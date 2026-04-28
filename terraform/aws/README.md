# Terraform / AWS (ap-northeast-1)

AWS Lightsail 上の k3s シングルノードと、それに付随する s3ql 用 S3 バケット / IAM ユーザを Terraform で管理します。`main.tf` から呼び出されるモジュールはサブディレクトリの README を参照してください。

| モジュール | 役割 | 詳細 |
| --- | --- | --- |
| [`./modules/lightsail`](./modules/lightsail/README.md) | k3s ノード本体 (Lightsail インスタンス / ZFS 用追加ディスク / Static IP / Key Pair / 公開ポート) | `module.lightsail` |
| [`./modules/s3`](./modules/s3/README.md) | 任意用途の S3 バケットと専用 IAM ユーザ (送信元 IP 制限つき) | `module.s3ql` (purpose=`s3ql`) |

## main.tf で作成されるリソース

```hcl
module "lightsail" {
  source  = "./modules/lightsail"
  project = local.project
}

module "s3ql" {
  source     = "./modules/s3"
  project    = local.project
  purpose    = "s3ql"
  allowed_ip = module.lightsail.k3s_public_ipv4
}
```

- `local.project = "su-nishi"` (`locals.tf`) — リソース名のプレフィックス。
- `module.lightsail` で k3s 用の Lightsail インスタンス・ZFS 用 128 GB 追加ディスク・Static IP (dualstack) などを構築する。
- `module.s3ql` で s3ql 用の S3 バケット (`su-nishi-s3ql-bucket`) と、Lightsail static IPv4 からのみアクセス可能な IAM ユーザを作成する。`allowed_ip` には `module.lightsail.k3s_public_ipv4` を渡しているため、Lightsail インスタンスを作り直して static IP が変わると IAM ポリシーも追従する。

## Provider / Backend

| 項目 | 値 |
| --- | --- |
| `terraform` required_version | `1.14.8` |
| `hashicorp/aws` | `6.41.0` |
| Region | `ap-northeast-1` |
| Backend | `s3` (`bucket=su-nishi-bucket`, `key=terraform/ap-northeast-1.tfstate`, `encrypt=true`) |
| Default tags | `CreatedBy = var.iam_user` |

backend に使う `su-nishi-bucket` はこの Terraform 構成の管理対象**外**で、事前に手動で作成・バージョニング有効化する必要があります (`provider.tf` 冒頭のコメント参照)。

```bash
aws s3api create-bucket --bucket su-nishi-bucket --region ap-northeast-1 \
  --create-bucket-configuration LocationConstraint=ap-northeast-1
aws s3api put-bucket-versioning --bucket su-nishi-bucket \
  --versioning-configuration Status=Enabled
```

## Outputs

`terraform output` で取得できる値は以下のとおり。s3ql の secret key だけは sensitive 扱い。

| Output | 内容 |
| --- | --- |
| `k3s_public_ipv4` | Lightsail static IPv4 |
| `k3s_public_ipv6` | Lightsail インスタンスの IPv6 アドレス |
| `s3ql_bucket_name` | s3ql 用 S3 バケット名 |
| `s3ql_bucket_arn` | s3ql 用 S3 バケット ARN |
| `s3ql_iam_user_name` | s3ql 用 IAM ユーザ名 |
| `s3ql_iam_access_key_id` | s3ql 用 IAM Access Key ID |
| `s3ql_iam_secret_access_key` | s3ql 用 IAM Secret Access Key (sensitive) |

これらの値は ansible 側の `host_vars/k3s-vps/vault.yml` に登録して s3ql から利用します (`../../ansible/README.md` の s3ql セットアップ節を参照)。

## Variables

| 変数 | 型 | 説明 |
| --- | --- | --- |
| `iam_user` | string | デフォルトタグ `CreatedBy` に入れる IAM ユーザ名。`make terraform.tfvars` で `aws iam get-user` から自動生成する |

## Usage

```bash
# IAM ユーザ名を terraform.tfvars に書き出す
make terraform.tfvars

# 通常の Terraform フロー
terraform init
terraform plan
terraform apply

# Secret Access Key を取り出す
terraform output -raw s3ql_iam_secret_access_key

# tfvars を消す
make clean
```

## Notes

- Lightsail インスタンスの user_data からは外部スクリプト (`https://akashisn.info/k3s_lightsail.sh`) が実行されます。元になっているのは [`./modules/lightsail/scripts/k3s_provisioner.sh`](./modules/lightsail/README.md) です。
- インスタンス作成後の手動セットアップ (Cloudflare Tunnel / Tailscale / ZFS プール / ZFSnap) は [`./modules/lightsail/README.md`](./modules/lightsail/README.md) を参照してください。
- s3ql の運用 (`mkfs.s3ql` の初回実行や mount/verify systemd unit) は ansible 側 (`../../ansible/README.md`) で管理します。
