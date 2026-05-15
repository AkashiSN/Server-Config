# Ansible

`k3s_cluster` インベントリグループ (server x1 + agent x2、AWS Lightsail / Ubuntu 24.04) を 3 ノード k3s クラスタとしてプロビジョニングします。

## Prerequisites

- 各ノードに Tailscale 経由 (または初回ブートストラップ時のみ public IPv4 経由) で SSH 到達できること
  - DNS は Tailscale MagicDNS (`<host>.<tailnet>.ts.net`) または `inventory.yml` の `ansible_host` (`<host>.akashisn.info`) を想定
- ローカルに `ansible` / `ansible-playbook` がインストール済みであること
- [1Password CLI (`op`)](https://developer.1password.com/docs/cli/) にサインイン済みで、`op://Private/ansible-vault/password` および `op://Private/ansible-vault/vault.yml` にアクセスできること
- Ansible collections のインストール

  ```bash
  ansible-galaxy collection install -r requirements.yml
  ```

## Layout

| パス | 役割 |
| --- | --- |
| `ansible.cfg` | inventory / vault パスワードファイル / python interpreter (3.12) の設定 |
| `inventory.yml` | `k3s_cluster` (`k3s_server` + `k3s_agent`) のホスト定義。各 host に `k3s_node_labels` を書けば `--node-label` で適用される |
| `vault-pass.sh` | 1Password から vault パスワードを読み取るスクリプト (`ansible.cfg` から参照) |
| `requirements.yml` | 必要な Ansible collections (`community.general`, `kubernetes.core`) |
| `setup-k3s-cluster.yml` | エントリ playbook (`node_facts` → `node_common` → `helm_cli` → `k3s_server` → `k3s_agent` → `cluster_*` の順に実行) |
| `group_vars/k3s_cluster/vars.yml` | 平文の共通変数 (k3s channel / TLS SAN / domain / ArgoCD / JuiceFS 設定) |
| `group_vars/k3s_cluster/vault.yml` | 暗号化済み secret (`make credential` で取得 / `ansible-vault` で編集) |
| `roles/node_facts/` | default NIC / private IPv4 / IPv6 prefix を register |
| `roles/node_common/` | hostname 設定 + パッケージ更新 + timezone / swap / logrotate |
| `roles/helm_cli/` | helm + helm-diff plugin |
| `roles/k3s_server/` | k3s server インストール + node-token を `k3s_token` fact に bind |
| `roles/k3s_agent/` | server の node-token (`hostvars['k3s-server'].k3s_token`) と private IP で agent join |
| `roles/cluster_ingress_nginx/` / `cluster_cert_manager/` / `cluster_argocd/` / `cluster_juicefs_csi/` | Helm リリースと付随リソース |
| `roles/cluster_app_secrets/` | アプリ用 namespace (`immich`, `nextcloud`) + 各 `*-secrets` (DB / OIDC / SMTP 等) を vault から投入 |

## 構築フロー

### 1. terraform で AWS 側を apply

```bash
cd ../terraform/aws
terraform apply
```

Lightsail インスタンス x3 (server: `medium_3_0` / agent: `xlarge_3_0`) + JuiceFS 用 Lightsail PostgreSQL + JuiceFS 用 S3 バケット & IAM ユーザが作成されます。userdata は `modules/lightsail_instance/scripts/k3s_node_provisioner.sh` が inline で渡され、SSH 鍵 / cloudflared / tailscale のパッケージインストールまでを行います (k3s 本体は ansible 側で導入)。

### 2. 初回ブートストラップ: 22 を一時開放して tailscale / cloudflared 認証

`terraform/aws/main.tf` の `module "k3s_cluster"` の `ports` 内に、コメントアウト済みの **22/TCP** エントリがある。これをアンコメントして `terraform apply` し、public IPv4 経由で各ノードに SSH 接続する:

```bash
cd ../terraform/aws
# main.tf の 22/TCP ブロックをアンコメントして apply
terraform apply

# 各ノードに SSH (公開鍵は provisioner shell が GitHub から流し込む)
ssh ubuntu@$(terraform output -raw k3s_cluster_server_public_ipv4)
```

server / agent それぞれで以下 2 つの認証を実施:

```bash
# Tailscale: tailnet に join (auth key は Tailscale 管理画面で発行)
sudo tailscale up --authkey=tskey-XXXX

# Cloudflare Tunnel: トンネル token を渡してサービス化
# (token は Cloudflare Zero Trust > Networks > Tunnels で発行)
sudo cloudflared service install <TUNNEL_TOKEN>
```

3 ノード全てで両方が完了したら、`main.tf` の 22/TCP ブロックを **再コメント** して `terraform apply` で port を閉じる。以降の SSH / ansible 接続は Tailscale または Cloudflare Tunnel 経由のみ。

### 3. `group_vars/k3s_cluster/vault.yml` の取得

1Password から vault ファイルをローカルに取得します。

```bash
make credential
```

内部で `op read "op://Private/ansible-vault/vault.yml" > group_vars/k3s_cluster/vault.yml` を実行します。`ansible.cfg` の `vault_password_file = vault-pass.sh` 経由で 1Password (`op://Private/ansible-vault/password`) から復号鍵が自動取得されます。

vault に登録すべき secret 一覧と取得元:

| キー | 取得元 | 取得コマンド例 |
| --- | --- | --- |
| `vault_tailnet_dns_name` | Tailscale 管理画面 (Tailnet name + `.ts.net`) | — |
| `vault_juicefs_metaurl` | terraform output から組み立て (PostgreSQL DSN、**パスワード抜き**) | 下記スニペット参照 |
| `vault_juicefs_meta_password` | terraform output (sensitive) | `terraform output -raw juicefs_db_master_password` |
| `vault_juicefs_s3_bucket` | terraform output | `terraform output -raw juicefs_s3_bucket_name` |
| `vault_juicefs_s3_access_key_id` | terraform output | `terraform output -raw juicefs_s3_iam_access_key_id` |
| `vault_juicefs_s3_secret_access_key` | terraform output (sensitive) | `terraform output -raw juicefs_s3_iam_secret_access_key` |
| `vault_postgres_backup_s3_bucket` | terraform output | `terraform output -raw postgres_backup_s3_bucket_name` |
| `vault_postgres_backup_s3_access_key_id` | terraform output | `terraform output -raw postgres_backup_s3_iam_access_key_id` |
| `vault_postgres_backup_s3_secret_access_key` | terraform output (sensitive) | `terraform output -raw postgres_backup_s3_iam_secret_access_key` |
| `vault_immich_walg_libsodium_key` | base64 32 byte (生成 + 1Password 登録 + 紙 QR 二重保管) | `openssl rand -base64 32` (詳細は [`../docs/postgres-walg-backup-ja.md`](../docs/postgres-walg-backup-ja.md)) |
| `vault_cloudflare_token` | Cloudflare ダッシュボード (DNS Edit 権限) | — |
| `vault_email` | ACME 登録用メールアドレス | — |
| `vault_argocd_oidc_issuer` | Cloudflare Zero Trust の OIDC アプリ | — |
| `vault_argocd_oidc_client_id` | 同上 | — |
| `vault_argocd_oidc_client_secret` | 同上 | — |
| `vault_argocd_webhook_github_secret` | GitHub webhook 用シークレット | — |
| `vault_immich_postgres_user_password` | Immich Postgres ユーザパスワード | — |
| `vault_nextcloud_email_address` | Nextcloud 通知メール from アドレス | — |
| `vault_nextcloud_smtp_password` | Nextcloud SMTP パスワード | — |
| `vault_nextcloud_admin_user` | Nextcloud 管理者ユーザ名 | — |
| `vault_nextcloud_admin_password` | Nextcloud 管理者パスワード | — |
| `vault_nextcloud_postgres_password` | Nextcloud Postgres パスワード | — |
| `vault_nextcloud_oidc_issuer` | Nextcloud OIDC issuer URL | — |
| `vault_nextcloud_oidc_client_id` | Nextcloud OIDC client id | — |
| `vault_nextcloud_oidc_client_secret` | Nextcloud OIDC client secret | — |

> **`K3S_TOKEN` は vault 登録不要**: k3s server が起動時に `/var/lib/rancher/k3s/server/node-token` を自動生成し、`roles/k3s_server` が slurp で `k3s_token` fact 化、`roles/k3s_agent` が `hostvars['k3s-server'].k3s_token` で参照します。

`vault_juicefs_metaurl` の組み立て例 (terraform/aws ディレクトリで実行)。**パスワードは含めない** こと:

```bash
JF_USER=$(terraform output -raw juicefs_db_master_username)
JF_HOST=$(terraform output -raw juicefs_db_endpoint)
JF_PORT=$(terraform output -raw juicefs_db_port)
echo "postgres://${JF_USER}@${JF_HOST}:${JF_PORT}/juicefs?sslmode=require"
```

パスワード (`vault_juicefs_meta_password`) は `terraform output -raw juicefs_db_master_password` で取得し、JuiceFS CSI secret の `envs` フィールド経由で `META_PASSWORD` 環境変数として注入される (URL エンコード不要、平文 secret に metaurl 全体を埋めない)。

### 4. プロビジョニング実行

```bash
make k3s-cluster
```

内部で `ansible-playbook setup-k3s-cluster.yml` を実行します。`vault-pass.sh` 経由で vault が復号されるため、事前に `op` のサインインが必要です。

順番:
1. `node_facts` で default NIC / private IPv4 を register
2. `node_common` で hostname / OS 基本設定
3. `k3s_server` で control-plane を起動 → node-token を fact 化
4. `k3s_agent` が server private IP + token で join
5. `cluster_ingress_nginx` / `cluster_cert_manager` / `cluster_argocd` / `cluster_juicefs_csi` を helm でデプロイ
6. `cluster_app_secrets` で `immich` / `nextcloud` namespace と `*-secrets` を投入
7. 全 pod が Ready になるまで待機

### 5. 動作確認

```bash
# kubectl を Tailscale 経由で繋ぐ (server から kubeconfig を取得)
scp k3s-server:.kube/config ~/.kube/config
sed -i '' "s/127.0.0.1/k3s-server/" ~/.kube/config
kubectl --kubeconfig ~/.kube/config get nodes -o wide

# k3s API (6443) が Lightsail public 側で閉じていることを確認
nmap -p 6443 $(cd ../terraform/aws && terraform output -raw k3s_cluster_server_public_ipv4)
# → filtered / closed であるべき (Tailscale 経由のみ)
```

### 6. ローカル credential の掃除

```bash
make clean
```

`group_vars/k3s_cluster/vault.yml` を削除します（リポジトリ外に漏らさないため）。再度プロビジョニングする場合は `make credential` で取り直します。

## node label の指定

`inventory.yml` の各 host エントリで `k3s_node_labels` を書くと `--node-label` が付与されます。

```yaml
k3s-agent-0:
  ansible_host: k3s-agent-0
  k3s_node_labels:
    - storage.immich=true
```

未指定なら何も付きません。

## ストレージ構成の概要

`k3s_cluster` 上のアプリ用永続データは原則 [JuiceFS](https://juicefs.com/docs/community/introduction) (S3 backed, クライアントサイド AES-GCM 暗号化) に集約しますが、**Postgres は例外として local-path-provisioner (root SSD 直接) に置きます**。理由は WAL fsync のレイテンシ要件で、JuiceFS (FUSE → S3) 上では commit/sec が大幅に劣化するため。

| 用途 | バックエンド | アクセス経路 |
| --- | --- | --- |
| Immich 写真 / Nextcloud ユーザデータ | JuiceFS (Lightsail PostgreSQL メタデータ + S3 オブジェクト) | JuiceFS CSI Driver (`storageClassName: juicefs`) |
| Immich Postgres / Nextcloud Postgres | k3s 同梱 local-path-provisioner (agent ノード root SSD) | `storageClassName: local-path` + `nodeSelector` で固定 (例: `storage.immich-db=true`) |
| Immich Postgres バックアップ (WAL-G) | 専用 S3 バケット (`module.postgres_backup_s3`、SSE-S3 + libsodium 二重暗号化) | StatefulSet 内 sidecar コンテナ + `archive_command` |

JuiceFS の `juicefs format` (一度だけ手動) / 暗号化鍵生成 / パスワードローテーション運用は [`../docs/juicefs-setup-ja.md`](../docs/juicefs-setup-ja.md)、Postgres バックアップ (WAL-G) の運用は [`../docs/postgres-walg-backup-ja.md`](../docs/postgres-walg-backup-ja.md) を参照してください。

## Notes

- Kubernetes 上のアプリ (dns / nextcloud / immich など) のマニフェストは [`../kubernetes/`](../kubernetes/README.md) 側で管理し、Argo CD ApplicationSet 経由で本クラスタに同期されます。
- AWS リソース (Lightsail インスタンス / 追加ディスク / Static IP / JuiceFS 用 PostgreSQL & S3 バケット & IAM ユーザ) は [`../terraform/aws/`](../terraform/aws/) で管理します。
