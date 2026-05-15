# Terraform / AWS (ap-northeast-1)

AWS Lightsail 上で稼働する k3s クラスタ (server x1 + agent x2) と、JuiceFS のメタデータエンジン用 Lightsail PostgreSQL、オブジェクトストレージ用 S3 バケットを Terraform で管理します。`main.tf` から呼び出されるモジュールはサブディレクトリの README を参照してください。

| モジュール | 役割 | 詳細 |
| --- | --- | --- |
| [`./modules/lightsail_instance`](./modules/lightsail_instance/README.md) | 汎用 Lightsail インスタンス (Lightsail インスタンス / 任意の追加ディスク / Static IP / Key Pair / 公開ポート) を `purpose` 単位で構築 | `module.k3s_cluster["server" / "agent-0" / "agent-1"]` |
| [`./modules/lightsail_database`](./modules/lightsail_database/README.md) | 汎用 Lightsail マネージド DB を `purpose` 単位で構築 | `module.lightsail_juicefs_db` (purpose=`juicefs`) |
| [`./modules/s3`](./modules/s3/README.md) | 任意用途の S3 バケットと専用 IAM ユーザ (送信元 IP 制限つき) | `module.juicefs_s3` (purpose=`juicefs`) / `module.postgres_backup_s3` (purpose=`postgres-backup`) |

## main.tf で作成されるリソース

```hcl
module "k3s_cluster" {
  for_each = local.k3s_cluster_nodes
  source   = "./modules/lightsail_instance"
  project  = local.project
  purpose  = each.value.purpose

  bundle_id = each.value.bundle_id
  user_data = file("${path.module}/modules/lightsail_instance/scripts/k3s_node_provisioner.sh")

  disks = {}

  ports = concat(
    each.value.role == "agent" ? [
      { protocol = "tcp", from_port = 443, to_port = 443, cidrs = ["0.0.0.0/0"], ipv6_cidrs = ["::/0"] },
    ] : [],
    [
      { protocol = "udp", from_port = 41641, to_port = 41641, cidrs = ["0.0.0.0/0"], ipv6_cidrs = ["::/0"] },
      # 初回ブートストラップ用 (使い終わったら再コメント)
      # { protocol = "tcp", from_port = 22, to_port = 22, cidrs = ["0.0.0.0/0"], ipv6_cidrs = ["::/0"] },
    ],
  )
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
  allowed_ips    = [for n in module.k3s_cluster : "${n.public_ipv4}/32"]
  admin_iam_user = var.iam_user
}
```

- `local.project = "su-nishi"` (`locals.tf`) — リソース名のプレフィックス。
- `local.k3s_cluster_nodes` (`locals.tf`) — server (`medium_3_0`) / agent-0 / agent-1 (`xlarge_3_0`) の 3 ノード定義。`for_each` で `module.k3s_cluster["<key>"]` として展開される。追加ディスクは作らず、bundle root SSD (medium=80GB / xlarge=320GB) で k3s ローカル領域 (containerd image, ephemeral, sqlite) と JuiceFS キャッシュを賄う。永続データは JuiceFS (S3 backed) に逃がす想定。
- `module.k3s_cluster` の `user_data` には [`./modules/lightsail_instance/scripts/k3s_node_provisioner.sh`](./modules/lightsail_instance/scripts/k3s_node_provisioner.sh) を inline で渡す。GitHub 公開鍵による SSH authorized_keys 上書き / cloudflared / tailscale のインストールまでで、k3s 本体は ansible (`../../ansible/setup-k3s-cluster.yml`) でセットアップする。
- `ports` で 6443 / 8472 / 10250 を public 開放してはいけない (kubectl は Tailscale 経由で `--tls-san` に登録した DNS / IP からのみ繋ぐ)。443 は ingress-nginx を載せる agent ノードのみ、41641 は tailscale 用に全ノードで開ける。22/TCP は初回ブートストラップ時のみ一時的にアンコメントして apply → tailscale / cloudflared 認証 → 再コメントして apply で塞ぐ。
- `module.lightsail_juicefs_db` で JuiceFS のメタデータエンジン用 Lightsail PostgreSQL 18 (`micro_2_0` プラン、single-AZ) を作成する。マスターパスワードは `random_password.juicefs_db` で生成し、output 経由でのみ取得できる。`lifecycle.ignore_changes = [master_password]` のため、初回 apply 後に Lightsail コンソールでローテートしても Terraform 側で drift にならない。
- `module.juicefs_s3` で JuiceFS のオブジェクトストレージ用 S3 バケット (`su-nishi-juicefs`) と、k3s クラスタ各ノードの static IPv4 からのみアクセス可能な IAM ユーザを作成する (private / SSE-AES256 / versioning + 7 日 lifecycle / IP 制限)。`allowed_ips` には `module.k3s_cluster` 全ノードの `public_ipv4/32` を渡しているため、いずれかのノードを作り直して static IP が変わると IAM ポリシーも追従する。
- 実際に JuiceFS を `juicefs format` / `juicefs mount` する手順は [`../../docs/juicefs-setup-ja.md`](../../docs/juicefs-setup-ja.md) を参照。クラスタへの helm デプロイは ansible 側 ([`../../ansible/README.md`](../../ansible/README.md)) で管理。

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

`terraform output` で取得できる値は以下のとおり。secret 系 (juicefs S3 secret access key、JuiceFS DB の master password) は sensitive 扱い。

| Output | 内容 |
| --- | --- |
| `k3s_cluster_server_public_ipv4` | server ノードの Lightsail static IPv4 |
| `k3s_cluster_server_private_ipv4` | server ノードの Lightsail private IPv4 |
| `k3s_cluster_agent_public_ipv4` | agent ノードの Lightsail static IPv4 (list) |
| `k3s_cluster_agent_private_ipv4` | agent ノードの Lightsail private IPv4 (list) |
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
| `postgres_backup_s3_bucket_name` | Postgres バックアップ (WAL-G) 用 S3 バケット名 |
| `postgres_backup_s3_bucket_arn` | Postgres バックアップ用 S3 バケット ARN |
| `postgres_backup_s3_iam_user_name` | Postgres バックアップ用 IAM ユーザ名 |
| `postgres_backup_s3_iam_access_key_id` | Postgres バックアップ用 IAM Access Key ID |
| `postgres_backup_s3_iam_secret_access_key` | Postgres バックアップ用 IAM Secret Access Key (sensitive) |

これらの値は ansible 側の `group_vars/k3s_cluster/vault.yml` に登録して JuiceFS CSI Driver / WAL-G sidecar から利用します ([`../../ansible/README.md`](../../ansible/README.md), [`../../docs/juicefs-setup-ja.md`](../../docs/juicefs-setup-ja.md), [`../../docs/postgres-walg-backup-ja.md`](../../docs/postgres-walg-backup-ja.md) を参照)。

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

# JuiceFS のメタデータ DB マスターパスワードを取り出す
terraform output -raw juicefs_db_master_password
# JuiceFS の S3 Secret Access Key を取り出す
terraform output -raw juicefs_s3_iam_secret_access_key

# tfvars を消す
make clean
```

## Notes

- Lightsail インスタンスの user_data は inline で [`./modules/lightsail_instance/scripts/k3s_node_provisioner.sh`](./modules/lightsail_instance/scripts/k3s_node_provisioner.sh) が渡されます。
- 初回ブートストラップ手順 (22/TCP の一時開放 → tailscale / cloudflared 認証 → 再コメント) は [`../../ansible/README.md`](../../ansible/README.md) のセットアップ節を参照してください。
- JuiceFS の `juicefs format` / パスワードローテーション運用は [`../../docs/juicefs-setup-ja.md`](../../docs/juicefs-setup-ja.md) を参照してください。
- `module.lightsail_juicefs_db` のマスターパスワードは初回 apply 時に `random_password` で 32 文字ランダム生成され、その値が tfstate に残ります。秘匿性を高めたい場合は apply 直後に Lightsail コンソール (`aws lightsail update-relational-database --master-user-password`) で別パスワードにローテートしてください (`lifecycle.ignore_changes` で Terraform 側の差分にはなりません)。
