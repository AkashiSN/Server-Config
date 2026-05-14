# Terraform

クラウド上のサーバーインフラを Terraform で管理するディレクトリ。

## ディレクトリ構成

| ディレクトリ | クラウド | 用途 |
|---|---|---|
| [aws](./aws) | AWS (ap-northeast-1) | Lightsail 上の k3s クラスタ (server x1 + agent x2) と JuiceFS 用 Lightsail PostgreSQL / S3 バケット |
| [oci](./oci) | OCI (ap-tokyo-1) | Oracle Cloud k3s インスタンスとネットワーク |

## aws

- **Backend**: S3 (`su-nishi`, `terraform/ap-northeast-1.tfstate`)
- **Provider**: `hashicorp/aws` 6.43.0 / Terraform 1.15.1
- **Modules**:
  - [lightsail_instance](./aws/modules/lightsail_instance) — 汎用 Lightsail インスタンスモジュール (purpose 単位でインスタンス + 追加ディスク + Static IP + キーペア + 公開ポートを構築。`module.k3s_cluster` から server / agent ノードをまとめて呼び出し)
  - [lightsail_database](./aws/modules/lightsail_database) — 汎用 Lightsail マネージド DB モジュール (JuiceFS メタデータ用 PostgreSQL 18 を作成)
  - [s3](./aws/modules/s3) — 任意用途の S3 バケット + 専用 IAM ユーザ (送信元 IP 制限つき。SSE-AES256, Public Access Block, versioning + 7d lifecycle、不完全マルチパートアップロード 7 日で中止)

詳細は [`./aws/README.md`](./aws/README.md) を参照。

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
