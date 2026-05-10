# JuiceFS セットアップ手順 (Lightsail PostgreSQL + S3)

`terraform/aws/main.tf` で構築した以下のリソースを使い、k3s インスタンス (`module.lightsail_k3s`) 上で JuiceFS をフォーマット・マウントするまでの手順をまとめる。

| 用途 | リソース | Terraform 参照 |
| --- | --- | --- |
| メタデータエンジン | Lightsail PostgreSQL 18 (`micro_2_0`, single-AZ) | `module.lightsail_juicefs_db` |
| マスターパスワード | `random_password` で生成、output に sensitive 公開 | `random_password.juicefs_db` |
| オブジェクトストレージ | S3 バケット (private / SSE-AES256 / versioning + 7d lifecycle) | `module.juicefs_s3` |
| S3 アクセス用 IAM ユーザ | k3s static IPv4 からのみ許可、専用 IAM ユーザ + access key | `module.juicefs_s3` (内部で `./modules/s3` を再利用) |

JuiceFS そのもののインストールや高度な使い方は公式 [JuiceFS Community Docs](https://juicefs.com/docs/community/) を参照。本書は **このリポジトリで作った AWS リソースをどう繋ぐか** に焦点を当てる。

## 前提

- `terraform/aws` 配下で `terraform apply` 済み (Lightsail DB / S3 バケット / IAM ユーザ作成済み)
- k3s インスタンス (`module.lightsail_k3s`) に SSH できる状態
- k3s インスタンスから JuiceFS Community Edition バイナリ (`juicefs`) を実行できる状態 (インストールは公式 [Quick Start Guide](https://juicefs.com/docs/community/quick_start_guide) または `curl -sSL https://d.juicefs.com/install | sh -` を参照)

## 1. 認証情報の取得

`terraform/aws` ディレクトリで以下を実行し、JuiceFS 接続に必要な値をすべて取得する。secret 系は sensitive output のため `-raw` で取り出す。

```bash
cd terraform/aws

# 公開情報 (そのままシェルにエクスポートして良い)
export JFS_DB_HOST=$(terraform output -raw juicefs_db_endpoint)
export JFS_DB_PORT=$(terraform output -raw juicefs_db_port)
export JFS_DB_USER=$(terraform output -raw juicefs_db_master_username)   # "juicefs"
export JFS_DB_NAME=juicefs
export JFS_S3_BUCKET=$(terraform output -raw juicefs_s3_bucket_name)
export JFS_S3_ACCESS_KEY=$(terraform output -raw juicefs_s3_iam_access_key_id)

# 機密情報 (シェル履歴・スクリーンショットに残らないよう注意)
export JFS_DB_PASS=$(terraform output -raw juicefs_db_master_password)
export JFS_S3_SECRET_KEY=$(terraform output -raw juicefs_s3_iam_secret_access_key)
```

これらの値は `terraform/aws/README.md` の Outputs 表にも対応関係を記載している。

## 2. メタデータ DB への接続テスト (任意)

JuiceFS から触る前に、PostgreSQL 接続が成立することを確認しておくとトラブルを切り分けやすい。Lightsail DB は `publicly_accessible=false` で作っているため、**k3s インスタンス上から実行する**。

```bash
# k3s インスタンス上で
PGPASSWORD="$JFS_DB_PASS" psql \
  "host=$JFS_DB_HOST port=$JFS_DB_PORT user=$JFS_DB_USER dbname=$JFS_DB_NAME sslmode=require" \
  -c '\conninfo'
```

`sslmode=require` を付けると AWS が出している自己署名証明書を信頼するだけで接続できる。証明書チェーンまで検証したい場合は `sslmode=verify-full` + AWS RDS の bundled CA を使う (Lightsail でも同じバンドルが流用できる)。

## 3. ファイルシステムの初期化 (`juicefs format`)

メタデータ DB に空のテーブル群を作成し、S3 バケットと紐付ける。**1 つのファイルシステムにつき 1 度だけ** 実行すればよい。

```bash
META_PASSWORD="$JFS_DB_PASS" juicefs format \
  --storage s3 \
  --bucket "https://${JFS_S3_BUCKET}.s3.ap-northeast-1.amazonaws.com" \
  --access-key "$JFS_S3_ACCESS_KEY" \
  --secret-key "$JFS_S3_SECRET_KEY" \
  "postgres://${JFS_DB_USER}@${JFS_DB_HOST}:${JFS_DB_PORT}/${JFS_DB_NAME}?sslmode=require" \
  myjfs
```

ポイント:

- **`META_PASSWORD` 環境変数** を使ってパスワードを渡す。URL に `:password@` で埋め込まないこと。プロセス一覧 (`ps`) や履歴に残るリスクを避けるため。
- **メタデータ URL の sslmode=require** を付ける。Lightsail PostgreSQL は SSL 強制ではないが、付けておくと万一公開設定に変わっても暗号化通信になる。
- **`--bucket` は仮想ホスト形式の URL** を使う (`https://<bucket>.s3.<region>.amazonaws.com`)。AWS S3 では path-style がレガシー扱いのため。
- 末尾の `myjfs` は **ファイルシステム名**。マウント時にも参照されるため、覚えやすい名前を付ける (本リポジトリの命名と揃えるなら `juicefs` でも可)。

成功すると以下のようなログが出て、PostgreSQL 側に約 14 個のテーブルが作成される。

```
<INFO>: Volume is formatted as ...
```

確認:

```bash
PGPASSWORD="$JFS_DB_PASS" psql \
  "host=$JFS_DB_HOST port=$JFS_DB_PORT user=$JFS_DB_USER dbname=$JFS_DB_NAME sslmode=require" \
  -c '\dt'
```

## 4. マウント (`juicefs mount`)

```bash
sudo mkdir -p /mnt/juicefs

META_PASSWORD="$JFS_DB_PASS" juicefs mount \
  --background \
  "postgres://${JFS_DB_USER}@${JFS_DB_HOST}:${JFS_DB_PORT}/${JFS_DB_NAME}?sslmode=require" \
  /mnt/juicefs
```

`--background` で daemon 化される。`df -h /mnt/juicefs` でマウント済みであることを確認する。`juicefs mount` は `juicefs format` と違い、**全クライアントで都度実行する** (k3s ノードが増えたらそれぞれで mount する)。

systemd 化する場合は公式 [Mount JuiceFS at boot](https://juicefs.com/docs/community/administration/mount_at_boot) を参照。`META_PASSWORD` を `EnvironmentFile=` で渡し、`/etc/juicefs/<volume>.env` のような分離ファイルを 0600 で配置するのが定石。

### k3s から使う場合

PVC として参照する場合は [JuiceFS CSI Driver](https://juicefs.com/docs/csi/introduction) を入れるのが王道。本リポジトリでは Helm/manifests の追加は本書の範囲外とするが、要点だけ:

- CSI Driver のインストールは `helm install juicefs-csi-driver` または manifests
- `Secret` に `metaurl` (`postgres://...`)、`access-key`、`secret-key`、`bucket` を入れる
- `metaurl` 内のパスワードは URL エンコードして埋め込むか、Secret 内の別フィールドに置いて CSI Driver の `format-options` から渡す

詳細は [Use JuiceFS in Kubernetes](https://juicefs.com/docs/csi/getting_started) を参照。

## 5. パスワードローテーション運用

Terraform の仕様上、`master_password` の初回値は tfstate に平文で残る。`module.lightsail_juicefs_db` は `lifecycle.ignore_changes = [master_password]` を持つため、**初回 apply 後に Lightsail コンソール / CLI で別パスワードにローテートしても Terraform 側の差分にはならない**。推奨フロー:

1. `terraform apply` で初回パスワードを設定 (`random_password.juicefs_db.result`)
2. 上記の Outputs から取得して `juicefs format` を実行 (一度きり)
3. AWS CLI で別パスワードにローテート

```bash
NEW_PASS=$(openssl rand -base64 24 | tr -d '/+=@" ')   # Lightsail 禁止文字を除去
aws lightsail update-relational-database \
  --region ap-northeast-1 \
  --relational-database-name su-nishi-juicefs \
  --master-user-password "$NEW_PASS" \
  --apply-immediately
```

4. `juicefs mount` 実行側 (k3s ノード / systemd unit / Kubernetes Secret) のパスワードを `$NEW_PASS` で更新
5. 以降のローテートはコンソール / CLI 側のみで完結。Terraform は触らない (state 上の値は使われていない過去のパスワードになる)

## 6. ファイルシステムを作り直す場合

JuiceFS は **メタデータ DB を空にすればファイルシステムを破棄したのと同義**。S3 バケットに残ったオブジェクトは孤児になるので、明示的に削除する。

```bash
# メタデータをクリア
PGPASSWORD="$JFS_DB_PASS" psql \
  "host=$JFS_DB_HOST port=$JFS_DB_PORT user=$JFS_DB_USER dbname=$JFS_DB_NAME sslmode=require" \
  -c 'DROP SCHEMA public CASCADE; CREATE SCHEMA public;'

# S3 バケットを空にする (バージョニング有効なので --include-versions が必要なツールもある)
aws s3 rm "s3://${JFS_S3_BUCKET}" --recursive
```

その後 `juicefs format` を再実行する。なお S3 バケット側のバージョニング + 7 日 lifecycle のため、削除直後は noncurrent version として 7 日残る (これは `module.juicefs_s3` のデフォルト)。

## 制約と注意点

- **single-AZ**: `bundle_id = "micro_2_0"` は single-AZ 構成。AZ 障害でメタデータ DB が消えると JuiceFS のファイルシステムも消える (S3 のオブジェクトは生きていてもメタデータがないので参照不能)。重要データを乗せる場合は `micro_ha_2_0` への移行 (Multi-AZ、約 2 倍コスト) を検討する。なお `bundle_id` の変更は destroy + create を伴うので、本番運用前に `skip_final_snapshot=false` + `final_snapshot_name` を設定してから移行すること。
- **拡張機能不可**: Lightsail マネージド DB は `shared_preload_libraries` を変更できないので、`pgvector` などの追加 extension は使えない。JuiceFS のメタデータエンジンは追加 extension を要求しないため問題はないが、同 DB を別用途に流用するのは避けた方がよい。
- **接続元の制約**: `publicly_accessible=false` で運用しているため、Lightsail アカウント外からは接続できない。同アカウントの他リージョンや別 VPC からの接続も不可。k3s ノード上で `juicefs mount` する以外の経路 (例: ローカルからの調査) を使う場合は、SSH ポートフォワードを使う。
- **S3 アクセス IP 制限**: `module.juicefs_s3` の IAM ポリシーは `module.lightsail_k3s.public_ipv4` からのみ許可。k3s インスタンスを作り直して static IP が変わると IAM ポリシーは Terraform で自動追従するが、IP が変わっている間 (apply 完了まで) は JuiceFS が S3 にアクセスできず動作不能になる。インスタンス再作成時は `juicefs mount` を停止してから実施するのが安全。
- **メタデータ消失=FS 消失**: 上述のとおり致命的。Lightsail 自動バックアップ (7 日保持、`backup_retention_enabled = true` がデフォルト有効) に加え、定期スナップショットの取得や、JuiceFS の `juicefs dump` によるメタデータエクスポートを併用するのが望ましい (公式 [Metadata Backup](https://juicefs.com/docs/community/administration/metadata_dump_load) 参照)。

## 参考

- 本リポジトリ
  - [`terraform/aws/README.md`](../terraform/aws/README.md)
  - [`terraform/aws/modules/lightsail_database/README.md`](../terraform/aws/modules/lightsail_database/README.md)
  - [`terraform/aws/modules/s3/README.md`](../terraform/aws/modules/s3/README.md)
- JuiceFS 公式
  - [Quick Start Guide](https://juicefs.com/docs/community/quick_start_guide)
  - [Set Up Metadata Engine — PostgreSQL](https://juicefs.com/docs/community/databases_for_metadata#postgresql)
  - [Set Up Object Storage — S3](https://juicefs.com/docs/community/how_to_set_up_object_storage#amazon-s3)
  - [Use JuiceFS on AWS](https://juicefs.com/docs/community/clouds/aws)
  - [JuiceFS CSI Driver](https://juicefs.com/docs/csi/introduction)
