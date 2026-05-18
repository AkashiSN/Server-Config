# Terraform / AWS / secrets (ap-northeast-1)

別 AWS アカウントの SSM Parameter Store に ansible-vault を put する Terraform プロジェクト。ansible 側 (`../../../../ansible/vault-pass.sh` / `Makefile`) の 1Password CLI 依存を SSM Parameter Store に置き換えることで、iPhone / iPad から SSH 経由で開発するときに 1Password の SSH 経由ロック解除問題を回避します。

| 項目 | 値 |
| --- | --- |
| Backend | S3: `akashisn-tfstate` (別アカウント) / `terraform/secrets/ap-northeast-1.tfstate` |
| プロファイル | `sylc` |
| `terraform` required_version | `1.15.1` |
| `hashicorp/aws` | `6.43.0` |
| Region | `ap-northeast-1` |
| Default tags | `CreatedBy = var.iam_user` |

- backend bucket `akashisn-tfstate` (別アカウント) は事前に手動作成 (versioning + encrypt 有効) しておくこと。手順は `provider.tf` の冒頭コメント参照。

## 構成

ansible-vault 暗号化済みの `vault_<group>.yml` 6 ファイルをドメイン単位に分割し、それぞれ Standard tier の SecureString として格納する。

| group | SSM パラメータ | 含まれる vault 変数 |
| --- | --- | --- |
| `common` | `/ansible/k3s_cluster/vault/common` | tailscale / cloudflare / email |
| `argocd` | `/ansible/k3s_cluster/vault/argocd` | argocd OIDC / webhook secret |
| `juicefs` | `/ansible/k3s_cluster/vault/juicefs` | juicefs meta + S3 認証情報 |
| `postgres_backup` | `/ansible/k3s_cluster/vault/postgres_backup` | WAL-G S3 認証情報 |
| `immich` | `/ansible/k3s_cluster/vault/immich` | immich postgres password / libsodium key |
| `nextcloud` | `/ansible/k3s_cluster/vault/nextcloud` | nextcloud SMTP / OIDC / DB 認証情報 |

- 各ファイルを手動で更新したあと `terraform apply` で差分を SSM に反映する。Terraform 側は `for_each` で 6 ファイルを一括管理。
- `vault_password` (`/ansible/k3s_cluster/vault_password`) は Terraform 管理外。`lifecycle.ignore_changes = [value]` で `PLACEHOLDER` のまま管理し、初回 apply 後に AWS コンソール / CLI で実値を入れる。
- ansible 側は `vault-pass.sh` / `Makefile` の `credential` ターゲットで `aws ssm get-parameter` を使って各 vault ファイルを復元する (`--profile sylc` 固定)。

## Variables

| 変数 | 型 | 説明 |
| --- | --- | --- |
| `iam_user` | string | デフォルトタグ `CreatedBy` に入れる IAM ユーザ名。`make terraform.tfvars` で `aws iam get-user` から自動生成する |

## Usage

```bash
cd terraform/aws/environment/secrets
make terraform.tfvars
terraform init
terraform plan
terraform apply

# 初回 apply 後、コンソールか CLI で vault_password の値を実際の vault パスワードに上書き
aws ssm put-parameter --name /ansible/k3s_cluster/vault_password \
  --type SecureString --value '<実際の vault password>' --overwrite

# tfvars を消す
make clean
```
