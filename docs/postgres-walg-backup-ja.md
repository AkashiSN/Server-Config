# Immich Postgres バックアップ運用 (WAL-G + 専用 S3 バケット)

`terraform/aws/environment/prod/main.tf` の `module "postgres_backup_s3"` で作成した専用 S3 バケットに、Immich Postgres (PG 14 + vectorchord + pgvector) のバックアップを **WAL-G** で取得・運用する手順をまとめる。Immich の admin UI から実行できる論理 dump (`pg_dumpall`) は併用継続。

| 役割 | 仕組み | RPO | 操作経路 |
| --- | --- | --- | --- |
| 物理 PITR、災害復旧、retention 35 日 | **WAL-G** (本書) | 5 分 (`archive_timeout=300`) | sidecar 自動 + `kubectl exec` |
| 単発の論理スナップショット (アップグレード前等) | Immich 標準 DB バックアップ | 任意 (UI 手動 or admin cron) | Immich Web UI (Admin Settings > Backups) |

## 構成

```
┌─────────── k3s_cluster (Lightsail) ───────────┐
│ agent-0 (label: storage.immich-db=true)        │
│ ┌─────────────────────────────────────────┐   │
│ │ StatefulSet immich-postgres-0           │   │
│ │  initContainer: wal-g-installer         │   │
│ │   (wget + tar → /shared/wal-g)          │   │
│ │  container: immich-postgres             │   │
│ │   archive_command = wal-g wal-push %p   │   │
│ │  container: wal-g-sidecar               │   │
│ │   loop: weekly backup-push + retain 4   │   │
│ │  volumes:                               │   │
│ │   data → local-path PVC (50Gi)          │   │
│ │   wal-g-bin → emptyDir (binary 共有)    │   │
│ │   pg-socket → emptyDir (peer 認証)      │   │
│ └─────────────────────────────────────────┘   │
└────────────┼───────────────────────────────────┘
             ▼ HTTPS (S3 API, libsodium 暗号化済み)
   ┌──────────────────────────────────┐
   │ s3://su-nishi-postgres-backup    │
   │  ├── immich/basebackups_005/     │  noncurrent_days=35
   │  └── immich/wal_005/             │  SSE-S3 + libsodium 二重
   └──────────────────────────────────┘
```

## 暗号化レイヤ

1. **S3 SSE-S3 (AES256)** — サーバサイド暗号化、自動 (`module.postgres_backup_s3` でデフォルト有効)
2. **WAL-G libsodium** — クライアントサイド AES-XChaCha20-Poly1305、`WALG_LIBSODIUM_KEY` (32 byte base64) で復号

二重化により、AWS S3 単独の compromise / k8s Secret 単独の流出のいずれでも平文には到達しない。**libsodium key を失うとバックアップは復号不能**になるため、保管は二重化必須 (1Password + 紙 QR / 別ホスト)。

## 初期セットアップ

### 1. Terraform で S3 バケット + IAM ユーザ作成

```bash
cd terraform/aws/environment/prod
terraform plan         # juicefs_s3 が non-destructive (noncurrent_days=7 維持) を確認
terraform apply

# postgres_backup_s3 は sensitive object output なので -json | jq -r で取り出す
terraform output -json postgres_backup_s3 | jq -r '.bucket_name'
terraform output -json postgres_backup_s3 | jq -r '.iam_access_key_id'
terraform output -json postgres_backup_s3 | jq -r '.iam_secret_access_key'
```

### 2. libsodium 暗号化キー生成 + 二重保管

```bash
# 32 byte ランダム → base64 (= 44 文字)
openssl rand -base64 32 > /tmp/walg-key.txt

# 1Password に登録
op item create \
  --category="API Credential" \
  --title="Immich WAL-G Libsodium" \
  --vault=Private \
  password="$(cat /tmp/walg-key.txt)"

# 紙 QR にバックアップ (耐火金庫等に保管)
qrencode -t ANSI < /tmp/walg-key.txt
qrencode -o /tmp/walg-key.png < /tmp/walg-key.txt   # 印刷用 PNG

# ローカルから消す
shred -u /tmp/walg-key.txt /tmp/walg-key.png
```

### 3. Ansible vault に登録 → ノードラベル & Secret 投入

vault は用途別に分割されているので、`postgres_backup` 系は `vault_postgres_backup.yml`、libsodium key は `vault_immich.yml` に書く ([`../ansible/README.md`](../ansible/README.md) の vault キー一覧参照)。

```bash
cd ansible
make credential
ansible-vault edit group_vars/k3s_cluster/vault_postgres_backup.yml
# 以下を追加:
#   vault_postgres_backup_s3_bucket: "<terraform output 値>"
#   vault_postgres_backup_s3_access_key_id: "<terraform output 値>"
#   vault_postgres_backup_s3_secret_access_key: "<terraform output 値>"

ansible-vault edit group_vars/k3s_cluster/vault_immich.yml
# 以下を追加:
#   vault_immich_walg_libsodium_key: "<openssl rand で生成した base64 値>"

# SSM Parameter Store に反映 (terraform/aws/environment/secrets が for_each で管理)
cd ../terraform/aws/environment/secrets && terraform apply && cd -

make k3s-cluster   # node label (storage.immich-db=true) + immich-postgres-walg Secret 投入

# 確認
kubectl --kubeconfig ~/.kube/config get nodes -L storage.immich-db
kubectl get secret -n immich immich-postgres-walg
```

### 4. Immich の新クラスタ用 manifests をデプロイ

```bash
# Argo CD 上に ApplicationSet を投入 (k3s_cluster 側の argocd 経由)
kubectl apply -f kubernetes/k3s_cluster/application.yml

# Pod 立ち上がり待機
kubectl get pod -n immich -w
# immich-postgres-0 が 2/2 Running になるまで (init → postgres + wal-g-sidecar)

# WAL-G binary 展開ログ
kubectl logs -n immich immich-postgres-0 -c wal-g-installer

# postgres の archive_command が有効か
kubectl exec -n immich immich-postgres-0 -c immich-postgres -- \
  psql -U postgres -c 'SHOW archive_command'
# → "/usr/local/wal-g/wal-g wal-push %p" であること
```

### 5. 初回 basebackup を手動実行

sidecar の自動ループは `sleep 604800` から始まるため、初回は手動で取る:

```bash
kubectl exec -n immich immich-postgres-0 -c wal-g-sidecar -- \
  /usr/local/wal-g/wal-g backup-push /var/lib/postgresql/data
```

## 状態確認コマンド集

```bash
# 世代一覧
kubectl exec -n immich immich-postgres-0 -c wal-g-sidecar -- \
  /usr/local/wal-g/wal-g backup-list

# 最新 basebackup の詳細
kubectl exec -n immich immich-postgres-0 -c wal-g-sidecar -- \
  /usr/local/wal-g/wal-g backup-show LATEST

# WAL アーカイブ状況 (連続性 / 欠損確認)
kubectl exec -n immich immich-postgres-0 -c wal-g-sidecar -- \
  /usr/local/wal-g/wal-g wal-show

# pg_wal の溜まり具合 (アーカイブ詰まり検知)
kubectl exec -n immich immich-postgres-0 -c immich-postgres -- \
  du -sh /var/lib/postgresql/data/pg_wal

# S3 側の object 一覧 (terraform/aws/environment/prod ディレクトリで)
aws s3 ls "s3://$(terraform output -json postgres_backup_s3 | jq -r '.bucket_name')/immich/" --recursive --human-readable
```

## PITR Restore 手順

`recovery_target_time` を指定して特定時点に復元する。**vectorchord / pgvectors の image tag (SHA256 digest) は採取時と完全一致させること** (extension binary の互換)。

### 1. Immich app を停止

```bash
# Argo CD で immich app の自動同期を一時停止
argocd app set immich --sync-policy none

# Pod を 0 にスケール (postgres は残す or 同時に scale 0)
kubectl scale -n immich deploy/immich-server --replicas=0
kubectl scale -n immich deploy/immich-microservices --replicas=0
kubectl scale -n immich deploy/immich-machine-learning --replicas=0
```

### 2. 復元先の PVC を空に

データを **完全に巻き戻す** ため、既存 PVC を削除して新規プロビジョニングする:

```bash
kubectl delete -n immich statefulset immich-postgres
kubectl delete -n immich pvc data-immich-postgres-0
# StatefulSet 再作成は kubectl apply -k kubernetes/k3s_cluster/immich で OK (Argo CD でも可)
kubectl apply -k kubernetes/k3s_cluster/immich
# postgres pod が起動するが、空 PGDATA に initdb が走る → これを止める必要がある
```

**注意**: 上記の素朴な手順は initdb が走ってしまう。実運用では「restore モードの専用 Pod を別 namespace で立ち上げる」方が安全。手順は以下:

### 2'. 別 namespace に restore 用 postgres を起動

```bash
kubectl create namespace immich-restore

# immich-postgres-walg Secret をコピー
kubectl get secret -n immich immich-postgres-walg -o yaml \
  | sed 's/namespace: immich/namespace: immich-restore/' \
  | kubectl apply -f -
kubectl get secret -n immich immich-secrets -o yaml \
  | sed 's/namespace: immich/namespace: immich-restore/' \
  | kubectl apply -f -

# 復元用 Pod を立ち上げる (wal-g 入りの postgres image を使い、PGDATA 空 + restore モード)
# 詳細は別途 restore-job manifest を準備するのが望ましい (Open Follow-ups 参照)
```

### 3. backup-fetch + recovery 設定

restore 用 postgres pod 内で:

```bash
# wal-g 環境変数は Secret 経由で展開済み
/usr/local/wal-g/wal-g backup-fetch /var/lib/postgresql/data LATEST
# 特定世代を指定する場合:
# /usr/local/wal-g/wal-g backup-fetch /var/lib/postgresql/data base_000000010000000000000003

# recovery 設定
cat >> /var/lib/postgresql/data/postgresql.auto.conf <<EOF
restore_command = '/usr/local/wal-g/wal-g wal-fetch %f %p'
recovery_target_time = '2026-05-14 10:00:00 JST'
recovery_target_action = 'promote'
EOF
touch /var/lib/postgresql/data/recovery.signal

# postgres を起動 → WAL replay → recovery_target_time で promote
postgres -D /var/lib/postgresql/data
```

ログに `recovery stopping at ...` → `database system is ready to accept connections` が出れば成功。

### 4. データ確認 → 本番に切り戻し

```bash
psql -U postgres -d immich -c '\dt' \
  | grep -i assets
psql -U postgres -d immich -c 'SELECT count(*) FROM assets'
```

数が妥当なら、PGDATA を本番 namespace の PVC にコピーして StatefulSet を再起動。または restore namespace 側を本番に昇格 (manifest を切り替え)。

## libsodium key ローテート

**鍵を変更すると、変更後に取った basebackup と WAL は新鍵でしか復号できない**。旧鍵で取った basebackup は **全 retention 期間が過ぎるまで** 旧鍵を保管する必要がある (現状 35 日 + 余裕)。

### 手順

1. 新鍵を生成 (`openssl rand -base64 32`)
2. 1Password に **新キー名** で登録 (例: `Immich WAL-G Libsodium 2026Q3`)、紙 QR バックアップも更新
3. `ansible-vault edit group_vars/k3s_cluster/vault_immich.yml` で `vault_immich_walg_libsodium_key` を新値に
4. `cd terraform/aws/environment/secrets && terraform apply` で SSM に反映 (→ 必要に応じて `make upload-credential` で 1Password 添付も更新)
5. `make k3s-cluster` で Secret 更新 → `kubectl rollout restart -n immich statefulset/immich-postgres`
6. **手動 basebackup 実行** (新鍵で取り直し):
   ```bash
   kubectl exec -n immich immich-postgres-0 -c wal-g-sidecar -- \
     /usr/local/wal-g/wal-g backup-push /var/lib/postgresql/data
   ```
7. 旧鍵で取った basebackup は引き続き S3 上に残るが、**新鍵では復号できない**。35 日 + 1 週で旧鍵を破棄して可。

## 四半期 Restore Drill

3 ヶ月に 1 回、別 namespace に LATEST を restore して `SELECT count(*) FROM assets` 等で件数を確認、件数が想定範囲なら drill PASS としてログに記録 (例: `docs/restore-drill-log.md`)。drill 失敗時は libsodium key / S3 IP allowlist / WAL の連続性をこの順で疑う。

## 帯域 / コスト監視

Lightsail の月次 egress (`xlarge_3_0` agent: 約 8 TB/月) に対して、JuiceFS と WAL-G が並行で S3 PUT する。目安:

- 週次 basebackup: Immich DB が 5 GB なら zstd 圧縮で約 2-3 GB → 月 12 GB
- WAL: `archive_timeout=300` で平均 10 KB/s × 86400 × 30 = 約 26 GB/月
- 合計 ~40 GB/月 (DB サイズに比例して増加)

Lightsail egress は十分余裕。ただし JuiceFS も含めると数百 GB/月になる可能性があるため、Lightsail のメトリクス画面で月次推移をチェック。閾値超えそうなら `WALG_DELTA_MAX_STEPS` を増やして増分頻度を上げる、`archive_timeout` を 600 秒に緩める、等で抑制可能。

## トラブルシューティング

### WAL アーカイブが詰まった (pg_wal 肥大)

`archive_command` が S3 障害等で繰り返し失敗すると、WAL セグメントがノードに溜まり続け `max_wal_size` を超えると Postgres 書き込みが刺さる。

```bash
# 状況確認
kubectl exec -n immich immich-postgres-0 -c immich-postgres -- \
  du -sh /var/lib/postgresql/data/pg_wal

# postgres 側のエラー
kubectl logs -n immich immich-postgres-0 -c immich-postgres | grep -i archiv

# 手動 push (sidecar で wal-g wal-push を直接実行) で詰まりを解消
kubectl exec -n immich immich-postgres-0 -c wal-g-sidecar -- bash -c '
  for f in /var/lib/postgresql/data/pg_wal/0*; do
    /usr/local/wal-g/wal-g wal-push "$f"
  done
'
```

S3 側の問題 (IP 制限変更、IAM 鍵失効、バケット削除) を切り分け、解消後に postgres コンテナを再起動して archive_command を再評価させる。

### libsodium key 紛失

復号不能。Restore は不可能。Immich 標準の論理 dump (UI 経由で取得した `pg_dumpall`) があればそちらから復元、無ければ Immich を空からセットアップし直して JuiceFS 上の写真原本だけ救出する。**だからこそ libsodium key の二重保管 + 四半期 drill が必須**。

### 採取時と異なる image で restore してしまった

vectorchord / pgvectors の C 拡張バイナリは PG メジャー + extension バージョン両方に依存。採取時と異なるバージョンで起動すると `extension X version mismatch` エラー、最悪は破損データ書き込み。

→ **常に SHA256 digest pinning** で image tag を固定し、`kubectl get pod immich-postgres-0 -o yaml | grep image:` で採取時の値を docs/restore-drill-log.md に控えておく。アップグレード時は `ALTER EXTENSION ... UPDATE` を `pg_basebackup` 取得**後**に実行し、新 basebackup を取り直す。

## 参考

- [WAL-G Documentation](https://wal-g.readthedocs.io/)
- [WAL-G PostgreSQL Configuration](https://github.com/wal-g/wal-g/blob/master/docs/PostgreSQL.md)
- [WAL-G Encryption (libsodium)](https://github.com/wal-g/wal-g/blob/master/docs/STORAGES.md#libsodium-encryption)
- 本リポジトリ
  - [`../terraform/aws/README.md`](../terraform/aws/README.md) — 全体構成 / backend
  - [`../terraform/aws/environment/prod/README.md`](../terraform/aws/environment/prod/README.md) — `module.postgres_backup_s3` の outputs と取り出し例
  - [`../terraform/aws/modules/s3/README.md`](../terraform/aws/modules/s3/README.md) (`noncurrent_days` の使い分け)
  - [`../ansible/README.md`](../ansible/README.md) (vault キー一覧と `cluster_app_secrets` ロール)
  - [`../kubernetes/k3s_cluster/immich/postgres.yml`](../kubernetes/k3s_cluster/immich/postgres.yml) (StatefulSet 実体)
