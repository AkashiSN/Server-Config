# Terraform / AWS (ap-northeast-1)

AWS Lightsail 上の k3s シングルノードと、それに付随する s3ql 用 S3 バケット / IAM ユーザ、JuiceFS のメタデータエンジン用 Lightsail PostgreSQL とオブジェクトストレージ用 S3 バケットを Terraform で管理します。`main.tf` から呼び出されるモジュールはサブディレクトリの README を参照してください。

| モジュール | 役割 | 詳細 |
| --- | --- | --- |
| [`./modules/lightsail_instance`](./modules/lightsail_instance/README.md) | 汎用 Lightsail インスタンス (Lightsail インスタンス / 任意の追加ディスク / Static IP / Key Pair / 公開ポート) を `purpose` 単位で構築 | `module.lightsail_k3s` (purpose=`k3s`) |
| [`./modules/lightsail_database`](./modules/lightsail_database/README.md) | 汎用 Lightsail マネージド DB を `purpose` 単位で構築 | `module.lightsail_juicefs_db` (purpose=`juicefs`) |
| [`./modules/s3`](./modules/s3/README.md) | 任意用途の S3 バケットと専用 IAM ユーザ (送信元 IP 制限つき) | `module.s3ql` (purpose=`s3ql`) / `module.juicefs_s3` (purpose=`juicefs`) |

## main.tf で作成されるリソース

```hcl
module "lightsail_k3s" {
  source  = "./modules/lightsail_instance"
  project = local.project
  purpose = "k3s"

  bundle_id = "xlarge_3_0"

  disks = {
    zfs = {
      size_in_gb = 128
      disk_path  = "/dev/xvdf"
    }
  }

  ports = [
    { protocol = "udp", from_port = 53, to_port = 53, cidrs = ["0.0.0.0/0"], ipv6_cidrs = ["::/0"] },
    { protocol = "tcp", from_port = 443, to_port = 443, cidrs = ["0.0.0.0/0"], ipv6_cidrs = ["::/0"] },
    { protocol = "tcp", from_port = 853, to_port = 853, cidrs = ["0.0.0.0/0"], ipv6_cidrs = ["::/0"] },
    { protocol = "udp", from_port = 51820, to_port = 51820, cidrs = ["0.0.0.0/0"], ipv6_cidrs = ["::/0"] },
  ]
}

module "s3ql" {
  source     = "./modules/s3"
  project    = local.project
  purpose    = "s3ql"
  allowed_ip = module.lightsail_k3s.public_ipv4
}

resource "random_password" "juicefs_db" {
  length           = 32
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

module "lightsail_juicefs_db" {
  source  = "./modules/lightsail_database"
  project = local.project
  purpose = "juicefs"

  blueprint_id = "postgres_18"
  bundle_id    = "micro_2_0"

  master_database_name = "juicefs"
  master_username      = "juicefs"
  master_password      = random_password.juicefs_db.result
}

module "juicefs_s3" {
  source         = "./modules/s3"
  project        = local.project
  purpose        = "juicefs"
  allowed_ip     = module.lightsail_k3s.public_ipv4
  admin_iam_user = var.iam_user
}
```

- `local.project = "su-nishi"` (`locals.tf`) — リソース名のプレフィックス。
- `module.lightsail_k3s` で k3s 用の Lightsail インスタンス・ZFS 用 128 GB 追加ディスク・Static IP (dualstack) などを構築する。`user_data` は `https://akashisn.info/${purpose}_lightsail.sh` (purpose=`k3s` のときは `k3s_lightsail.sh`) を curl|bash する。
- `module.s3ql` で s3ql 用の S3 バケット (`su-nishi-s3ql`) と、Lightsail static IPv4 からのみアクセス可能な IAM ユーザを作成する。`allowed_ip` には `module.lightsail_k3s.public_ipv4` を渡しているため、Lightsail インスタンスを作り直して static IP が変わると IAM ポリシーも追従する。
- `module.lightsail_juicefs_db` で JuiceFS のメタデータエンジン用 Lightsail PostgreSQL 18 (`micro_2_0` プラン、single-AZ) を作成する。マスターパスワードは `random_password.juicefs_db` で生成し、output 経由でのみ取得できる。`lifecycle.ignore_changes = [master_password]` のため、初回 apply 後に Lightsail コンソールでローテートしても Terraform 側で drift にならない。
- `module.juicefs_s3` で JuiceFS のオブジェクトストレージ用 S3 バケット (`su-nishi-juicefs`) と、Lightsail static IPv4 からのみアクセス可能な IAM ユーザを作成する。`module.s3ql` と同じ `./modules/s3` を `purpose=juicefs` で再利用しているだけで、構成 (private / SSE-AES256 / versioning + 7 日 lifecycle / IP 制限) も同一。
- 実際に JuiceFS を `juicefs format` / `juicefs mount` する手順は [`../../docs/juicefs-setup-ja.md`](../../docs/juicefs-setup-ja.md) を参照。

## Provider / Backend

| 項目 | 値 |
| --- | --- |
| `terraform` required_version | `1.15.1` |
| `hashicorp/aws` | `6.43.0` |
| `hashicorp/random` | `~> 3.6` |
| Region | `ap-northeast-1` |
| Backend | `s3` (`bucket=su-nishi`, `key=terraform/ap-northeast-1.tfstate`, `encrypt=true`) |
| Default tags | `CreatedBy = var.iam_user` |

backend に使う `su-nishi` バケットはこの Terraform 構成の管理対象**外**で、事前に手動で作成・バージョニング有効化する必要があります (`provider.tf` 冒頭のコメント参照)。

```bash
aws s3api create-bucket --bucket su-nishi --region ap-northeast-1 \
  --create-bucket-configuration LocationConstraint=ap-northeast-1
aws s3api put-bucket-versioning --bucket su-nishi \
  --versioning-configuration Status=Enabled
```

## Outputs

`terraform output` で取得できる値は以下のとおり。secret 系 (s3ql / juicefs の access secret key、JuiceFS DB の master password) は sensitive 扱い。

| Output | 内容 |
| --- | --- |
| `k3s_public_ipv4` | Lightsail static IPv4 |
| `k3s_public_ipv6` | Lightsail インスタンスの IPv6 アドレス |
| `s3ql_bucket_name` | s3ql 用 S3 バケット名 |
| `s3ql_bucket_arn` | s3ql 用 S3 バケット ARN |
| `s3ql_iam_user_name` | s3ql 用 IAM ユーザ名 |
| `s3ql_iam_access_key_id` | s3ql 用 IAM Access Key ID |
| `s3ql_iam_secret_access_key` | s3ql 用 IAM Secret Access Key (sensitive) |
| `juicefs_db_endpoint` | JuiceFS メタデータ DB の接続ホスト名 |
| `juicefs_db_port` | JuiceFS メタデータ DB のポート (PostgreSQL: 5432) |
| `juicefs_db_engine` | JuiceFS メタデータ DB のエンジン (`postgres`) |
| `juicefs_db_engine_version` | JuiceFS メタデータ DB のエンジンバージョン |
| `juicefs_db_master_username` | JuiceFS メタデータ DB のマスターユーザ名 (`juicefs`) |
| `juicefs_db_master_password` | JuiceFS メタデータ DB のマスターパスワード (sensitive) |
| `juicefs_s3_bucket_name` | JuiceFS オブジェクトストレージ用 S3 バケット名 |
| `juicefs_s3_bucket_arn` | JuiceFS オブジェクトストレージ用 S3 バケット ARN |
| `juicefs_s3_iam_user_name` | JuiceFS 用 IAM ユーザ名 |
| `juicefs_s3_iam_access_key_id` | JuiceFS 用 IAM Access Key ID |
| `juicefs_s3_iam_secret_access_key` | JuiceFS 用 IAM Secret Access Key (sensitive) |

これらの値は ansible 側の `host_vars/k3s-vps/vault.yml` に登録して s3ql / JuiceFS から利用します (`../../ansible/README.md` の各セットアップ節と [`../../docs/juicefs-setup-ja.md`](../../docs/juicefs-setup-ja.md) を参照)。

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

# JuiceFS のメタデータ DB マスターパスワードを取り出す
terraform output -raw juicefs_db_master_password
# JuiceFS の S3 Secret Access Key を取り出す
terraform output -raw juicefs_s3_iam_secret_access_key

# tfvars を消す
make clean
```

## Notes

- Lightsail インスタンスの user_data からは外部スクリプト (`https://akashisn.info/${purpose}_lightsail.sh`、purpose=`k3s` のときは `https://akashisn.info/k3s_lightsail.sh`) が実行されます。元になっているのは [`./modules/lightsail_instance/scripts/k3s_provisioner.sh`](./modules/lightsail_instance/README.md) です。
- インスタンス作成後の手動セットアップ (Cloudflare Tunnel / Tailscale / ZFS プール / ZFSnap) は [`./modules/lightsail_instance/README.md`](./modules/lightsail_instance/README.md) を参照してください。
- s3ql の運用 (`mkfs.s3ql` の初回実行や mount/verify systemd unit) は ansible 側 (`../../ansible/README.md`) で管理します。
- JuiceFS の `juicefs format` / `juicefs mount` / パスワードローテーション運用は [`../../docs/juicefs-setup-ja.md`](../../docs/juicefs-setup-ja.md) を参照してください。
- `module.lightsail_juicefs_db` のマスターパスワードは初回 apply 時に `random_password` で 32 文字ランダム生成され、その値が tfstate に残ります。秘匿性を高めたい場合は apply 直後に Lightsail コンソール (`aws lightsail update-relational-database --master-user-password`) で別パスワードにローテートしてください (`lifecycle.ignore_changes` で Terraform 側の差分にはなりません)。
