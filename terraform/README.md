# Terraform

クラウド上のサーバーインフラを Terraform で管理するディレクトリ。

## ディレクトリ構成

| ディレクトリ | クラウド | 用途 |
|---|---|---|
| [aws](./aws) | AWS (ap-northeast-1) | Lightsail 上の k3s クラスタ (server x1 + agent x2) と JuiceFS 用 Lightsail PostgreSQL / S3 バケット |
| [oci](./oci) | OCI (ap-tokyo-1) | Oracle Cloud k3s インスタンスとネットワーク |

## aws

- **Provider**: `hashicorp/aws` 6.43.0 / Terraform 1.15.1
- **Environments** (`./aws/environment/<env>` 配下にそれぞれ独立した tfstate):
  - [prod](./aws/environment/prod) — 本番 k3s クラスタ (server×1 + agent×2) + JuiceFS 用 Lightsail PostgreSQL + S3 群。Backend: S3 (`su-nishi`, `terraform/prod/ap-northeast-1.tfstate`)
  - [dev](./aws/environment/dev) — リモート SSH 開発用 Lightsail 1 台 (`small_3_0`)。Backend: S3 (`su-nishi`, `terraform/dev/ap-northeast-1.tfstate`)
  - [secrets](./aws/environment/secrets) — 別 AWS アカウントの SSM Parameter Store に ansible-vault を put。direnv で `AWS_PROFILE` を切替。Backend: 別アカウントの S3
- **Modules** (環境間で共有):
  - [lightsail_instance](./aws/modules/lightsail_instance) — 汎用 Lightsail インスタンスモジュール (purpose 単位でインスタンス + 追加ディスク + Static IP + キーペア + 公開ポートを構築)
  - [lightsail_database](./aws/modules/lightsail_database) — 汎用 Lightsail マネージド DB モジュール
  - [s3](./aws/modules/s3) — 任意用途の S3 バケット + 専用 IAM ユーザ (送信元 IP 制限つき)

詳細は [`./aws/README.md`](./aws/README.md) を参照。

### 実行手順

```bash
cd terraform/aws/environment/<env>   # prod / dev / secrets
make terraform.tfvars                # 実行中のIAMユーザー名を tfvars に書き出す (secrets は direnv allow も)
terraform init
terraform plan
terraform apply
```

## oci

- **Backend**: OCI Object Storage (`snishi-bucket`, `terraform/ap-tokyo-1.tfstate`)
- **Provider**: `oracle/oci` 7.22.0
- **構成**: VCN / Subnet / Route Table / Internet Gateway / NSG / Compute インスタンス (VM.Standard.E4.Flex, 4 OCPU / 16GB) / Block Volume 2048GB / Reserved Public IP

### 開放ポート

| ポート | プロトコル | 用途 |
|---|---|---|
| 53 | UDP | DNS |
| 443 | TCP | HTTPS |
| 853 | TCP | DoH |
| 51820 | UDP | WireGuard |

### 実行手順

```bash
cd terraform/oci
terraform init
terraform plan
terraform apply
```

`terraform.tfvars` に `compartment_id` と `ssh_public_key` を設定しておく。
