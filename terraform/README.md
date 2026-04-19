# Terraform

クラウド上のサーバーインフラを Terraform で管理するディレクトリ。

## ディレクトリ構成

| ディレクトリ | クラウド | 用途 |
|---|---|---|
| [aws](./aws) | AWS (ap-northeast-1) | Lightsail 上の k3s インスタンスと、s3ql 用の S3 バケット |
| [oci](./oci) | OCI (ap-tokyo-1) | Oracle Cloud k3s インスタンスとネットワーク |

## aws

- **Backend**: S3 (`su-nishi-bucket`, `terraform/ap-northeast-1.tfstate`)
- **Provider**: `hashicorp/aws` 6.41.0 / Terraform 1.14.8
- **Modules**:
  - [lightsail](./aws/modules/lightsail) — k3s 用 Lightsail インスタンス + ZFS 用ディスク + Static IP + キーペア
  - [s3](./aws/modules/s3) — s3ql 用 S3 バケット (SSE-S3, Public Access Block, 不完全マルチパートアップロード 7 日で中止)

### 実行手順

```bash
cd terraform/aws
make terraform.tfvars   # 実行中のIAMユーザー名を tfvars に書き出す
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
