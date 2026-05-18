# Terraform / AWS / dev (ap-northeast-1)

リモート SSH 開発用 Lightsail 1 台 (`small_3_0`) を管理する Terraform プロジェクト。本番 k3s クラスタには参加しない。

| 項目 | 値 |
| --- | --- |
| Backend | S3: `su-nishi-tfstate` / `terraform/dev/ap-northeast-1.tfstate` |
| プロファイル | 自アカウントの default プロファイル |
| `terraform` required_version | `1.15.3"` |
| `hashicorp/aws` | `6.45.0` |
| Region | `ap-northeast-1` |
| Default tags | `CreatedBy = var.iam_user` |

## 構成

- SSH 経由でソースを置いて開発するための単独 Lightsail ノード。`local.project = "su-nishi-dev"` (`locals.tf`)。
- [`../../modules/lightsail_instance/scripts/dev_node_provisioner.sh`](../../modules/lightsail_instance/scripts/dev_node_provisioner.sh) は GitHub 公開鍵で SSH authorized_keys を上書き → tailscale / cloudflared / 開発用パッケージ (git / make / build-essential / jq) をインストール。tailscale / cloudflared の認証は手動。
- `ports` は tailscale (41641/UDP) のみ。22/TCP は初回ブートストラップ時のみ一時的にアンコメントして apply → tailscale / cloudflared 認証 → 再コメントして apply で塞ぐ。

## Outputs

| Output | 内容 |
| --- | --- |
| `dev_node_public_ipv4` | dev ノードの Lightsail static IPv4 |
| `dev_node_private_ipv4` | dev ノードの private IPv4 |

## Variables

| 変数 | 型 | 説明 |
| --- | --- | --- |
| `iam_user` | string | デフォルトタグ `CreatedBy` に入れる IAM ユーザ名。`make terraform.tfvars` で `aws iam get-user` から自動生成する |

## Usage

```bash
cd terraform/aws/environment/dev
make terraform.tfvars
terraform init
terraform plan
terraform apply

# tfvars を消す
make clean
```

## Notes

- 初回ブートストラップ手順 (22/TCP の一時開放 → tailscale / cloudflared 認証 → 再コメント) は [`../../../../ansible/README.md`](../../../../ansible/README.md) のセットアップ節を参照してください。
- backend に使う `su-nishi` バケットは Terraform 管理対象**外**で、事前に手動で作成・バージョニング有効化する必要があります (詳細は [`../../README.md`](../../README.md))。
