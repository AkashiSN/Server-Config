# Terraform / AWS (ap-northeast-1)

AWS リソースを 3 つの独立した Terraform プロジェクトに分割して管理します。各プロジェクトは `./environment/<env>` 配下にあり、tfstate も環境ごとに分離されています。共通のモジュールは `./modules/` 配下に置き、各環境から `../../modules/...` で参照します。

## 環境一覧

| 環境 | スコープ | Backend | プロファイル |
| --- | --- | --- | --- |
| [`environment/prod`](./environment/prod/) | 本番 k3s クラスタ (server×1 + agent×2) + JuiceFS 用 Lightsail PostgreSQL + S3 (juicefs / postgres-backup) | S3: `su-nishi` / `terraform/prod/ap-northeast-1.tfstate` | 自アカウントの default プロファイル |
| [`environment/dev`](./environment/dev/) | リモート SSH 開発用 Lightsail 1 台 (`small_3_0`) | S3: `su-nishi` / `terraform/dev/ap-northeast-1.tfstate` | 自アカウントの default プロファイル |
| [`environment/secrets`](./environment/secrets/) | 別 AWS アカウントの SSM Parameter Store に ansible-vault を put | S3: 別アカウントの専用バケット / `terraform/secrets/ap-northeast-1.tfstate` | direnv (`.envrc`) で `AWS_PROFILE` を別アカウントに切替 |

## 共通モジュール

| モジュール | 役割 |
| --- | --- |
| [`./modules/lightsail_instance`](./modules/lightsail_instance/README.md) | 汎用 Lightsail インスタンス (Lightsail インスタンス / 任意の追加ディスク / Static IP / Key Pair / 公開ポート) を `purpose` 単位で構築。`scripts/k3s_node_provisioner.sh` (本番) と `scripts/dev_node_provisioner.sh` (開発) を同梱 |
| [`./modules/lightsail_database`](./modules/lightsail_database/README.md) | 汎用 Lightsail マネージド DB を `purpose` 単位で構築 |
| [`./modules/s3`](./modules/s3/README.md) | 任意用途の S3 バケットと専用 IAM ユーザ (送信元 IP 制限つき) |

---

## `environment/prod`

```hcl
module "k3s_cluster" {
  for_each = local.k3s_cluster_nodes
  source   = "../../modules/lightsail_instance"
  project  = local.project
  purpose  = each.value.purpose

  bundle_id = each.value.bundle_id
  user_data = file("${path.module}/../../modules/lightsail_instance/scripts/k3s_node_provisioner.sh")

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
  source  = "../../modules/lightsail_database"
  project = local.project
  purpose = "juicefs"

  blueprint_id = "postgres_18"
  bundle_id    = "micro_2_0"

  master_database_name = "juicefs"
  master_username      = "juicefs"
  master_password      = random_password.juicefs_db.result
}

module "juicefs_s3" {
  source         = "../../modules/s3"
  project        = local.project
  purpose        = "juicefs"
  allowed_ips    = [for n in module.k3s_cluster : "${n.public_ipv4}/32"]
  admin_iam_user = var.iam_user
}

module "postgres_backup_s3" {
  source          = "../../modules/s3"
  project         = local.project
  purpose         = "postgres-backup"
  allowed_ips     = [for n in module.k3s_cluster : "${n.public_ipv4}/32"]
  admin_iam_user  = var.iam_user
  noncurrent_days = 35
}
```

- `local.project = "su-nishi"` (`locals.tf`) — リソース名のプレフィックス。
- `local.k3s_cluster_nodes` (`locals.tf`) — server (`medium_3_0`) / agent-0 / agent-1 (`xlarge_3_0`) の 3 ノード定義。`for_each` で `module.k3s_cluster["<key>"]` として展開される。追加ディスクは作らず、bundle root SSD (medium=80GB / xlarge=320GB) で k3s ローカル領域と JuiceFS キャッシュを賄う。永続データは JuiceFS (S3 backed) に逃がす想定。
- `module.k3s_cluster` の `user_data` には [`../../modules/lightsail_instance/scripts/k3s_node_provisioner.sh`](./modules/lightsail_instance/scripts/k3s_node_provisioner.sh) を inline で渡す。GitHub 公開鍵による SSH authorized_keys 上書き / cloudflared / tailscale のインストールまでで、k3s 本体は ansible (`../../../ansible/setup-k3s-cluster.yml`) でセットアップする。
- `ports` で 6443 / 8472 / 10250 を public 開放してはいけない (kubectl は Tailscale 経由で `--tls-san` に登録した DNS / IP からのみ繋ぐ)。443 は ingress-nginx を載せる agent ノードのみ、41641 は tailscale 用に全ノードで開ける。22/TCP は初回ブートストラップ時のみ一時的にアンコメントして apply → tailscale / cloudflared 認証 → 再コメントして apply で塞ぐ。
- `module.lightsail_juicefs_db` で JuiceFS のメタデータエンジン用 Lightsail PostgreSQL 18 (`micro_2_0` プラン、single-AZ) を作成する。マスターパスワードは `random_password.juicefs_db` で生成し、output 経由でのみ取得できる。`lifecycle.ignore_changes = [master_password]` のため、初回 apply 後に Lightsail コンソールでローテートしても Terraform 側で drift にならない。
- `module.juicefs_s3` で JuiceFS のオブジェクトストレージ用 S3 バケット (`su-nishi-juicefs`) と、k3s クラスタ各ノードの static IPv4 からのみアクセス可能な IAM ユーザを作成する。
- `module.postgres_backup_s3` で Immich Postgres (将来的には Nextcloud Postgres も) の WAL-G バックアップ用 S3 バケット (`su-nishi-postgres-backup`) を作成する。`noncurrent_days = 35` で WAL-G 側の `wal-g delete retain FULL 4` と整合させる。
- 実際に JuiceFS を `juicefs format` / `juicefs mount` する手順は [`../../docs/juicefs-setup-ja.md`](../../docs/juicefs-setup-ja.md) を、WAL-G の運用手順は [`../../docs/postgres-walg-backup-ja.md`](../../docs/postgres-walg-backup-ja.md) を参照。

### prod Outputs

| Output | 内容 |
| --- | --- |
| `k3s_cluster_server_public_ipv4` / `k3s_cluster_server_private_ipv4` | server ノードの Lightsail static / private IPv4 |
| `k3s_cluster_agent_public_ipv4` / `k3s_cluster_agent_private_ipv4` | agent ノードの IPv4 (list) |
| `juicefs_db_endpoint` / `juicefs_db_port` / `juicefs_db_engine` / `juicefs_db_engine_version` | JuiceFS メタデータ DB の接続情報 |
| `juicefs_db_master_username` / `juicefs_db_master_password` | JuiceFS DB の認証情報 (password は sensitive) |
| `juicefs_s3_bucket_name` / `juicefs_s3_bucket_arn` / `juicefs_s3_iam_user_name` / `juicefs_s3_iam_access_key_id` / `juicefs_s3_iam_secret_access_key` | JuiceFS 用 S3 と IAM (secret は sensitive) |
| `postgres_backup_s3_*` | Postgres バックアップ用 S3 と IAM (上記と同形、secret は sensitive) |

これらの値は ansible 側の `group_vars/k3s_cluster/vault.yml` に登録して JuiceFS CSI Driver / WAL-G sidecar から利用します。

---

## `environment/dev`

```hcl
module "dev_node" {
  source  = "../../modules/lightsail_instance"
  project = local.project          # "su-nishi-dev"
  purpose = "dev"

  bundle_id = "small_3_0"
  user_data = file("${path.module}/../../modules/lightsail_instance/scripts/dev_node_provisioner.sh")

  disks = {}
  ports = [
    { protocol = "udp", from_port = 41641, to_port = 41641, cidrs = ["0.0.0.0/0"], ipv6_cidrs = ["::/0"] },
    # 初回ブートストラップ用 (使い終わったら再コメント)
    # { protocol = "tcp", from_port = 22, to_port = 22, cidrs = ["0.0.0.0/0"], ipv6_cidrs = ["::/0"] },
  ]
}
```

- SSH 経由でソースを置いて開発するための単独 Lightsail ノード。本番 k3s クラスタには参加しない。
- `dev_node_provisioner.sh` は GitHub 公開鍵で SSH authorized_keys を上書き → tailscale / cloudflared / 開発用パッケージ (git / make / build-essential / jq) をインストール。tailscale / cloudflared の認証は手動。
- Outputs: `dev_node_public_ipv4` / `dev_node_private_ipv4`

---

## `environment/secrets`

別 AWS アカウントの SSM Parameter Store に ansible-vault を置くプロジェクト。ansible 側 (`../../ansible/vault-pass.sh` / `Makefile`) の 1Password CLI 依存を SSM Parameter Store に置き換えることで、iPhone / iPad から SSH 経由で開発するときに 1Password の SSH 経由ロック解除問題を回避します。

- 別アカウントへの認証は **direnv** で `AWS_PROFILE` を切り替える前提 (assume_role なし)。`./environment/secrets/.envrc` の `AWS_PROFILE` を実際のプロファイル名に書き換え、`direnv allow` で有効化。
- backend bucket (別アカウントの S3) は事前に手動作成 (versioning + encrypt) し、`provider.tf` の bucket 名を書き換え。

```hcl
resource "aws_ssm_parameter" "ansible_vault_yml" {
  name   = "/ansible/k3s_cluster/vault_yml"
  type   = "SecureString"
  tier   = "Advanced"   # vault.yml は 4KB 超の可能性があるため
  value  = file("${path.module}/../../../../ansible/group_vars/k3s_cluster/vault.yml")
}

resource "aws_ssm_parameter" "ansible_vault_password" {
  name  = "/ansible/k3s_cluster/vault_password"
  type  = "SecureString"
  value = "PLACEHOLDER"
  lifecycle { ignore_changes = [value] }  # 値は手動で投入する
}
```

- `vault.yml` 本体は ansible-vault で暗号化済みのテキストをそのまま SecureString に格納する。vault.yml を手動で更新したあと `terraform apply` で差分を SSM に反映する。
- `vault_password` は Terraform 管理外。初回 apply 後に AWS コンソール / CLI で実値を入れる (`lifecycle.ignore_changes = [value]`)。
- ansible 側 (`vault-pass.sh`, `Makefile`) を SSM 取得に書き換える作業は本プロジェクトのスコープ外 (別 PR で対応)。

---

## Provider / Backend

| 項目 | prod | dev | secrets |
| --- | --- | --- | --- |
| `terraform` required_version | `1.15.1` | `1.15.1` | `1.15.1` |
| `hashicorp/aws` | `6.43.0` | `6.43.0` | `6.43.0` |
| `hashicorp/random` | `~> 3.6` | – | – |
| Region | `ap-northeast-1` | `ap-northeast-1` | `ap-northeast-1` |
| Backend bucket | `su-nishi` | `su-nishi` | 別アカウントの専用バケット |
| Backend key | `terraform/prod/ap-northeast-1.tfstate` | `terraform/dev/ap-northeast-1.tfstate` | `terraform/secrets/ap-northeast-1.tfstate` |
| Default tags | `CreatedBy = var.iam_user` | 同左 | 同左 |

backend に使う `su-nishi` バケットおよび secrets 用の別アカウントバケットは Terraform 管理対象**外**で、事前に手動で作成・バージョニング有効化する必要があります。

```bash
aws s3api create-bucket --bucket su-nishi --region ap-northeast-1 \
  --create-bucket-configuration LocationConstraint=ap-northeast-1
aws s3api put-bucket-versioning --bucket su-nishi \
  --versioning-configuration Status=Enabled
```

## Variables

| 変数 | 型 | 環境 | 説明 |
| --- | --- | --- | --- |
| `iam_user` | string | 全環境 | デフォルトタグ `CreatedBy` に入れる IAM ユーザ名。`make terraform.tfvars` で `aws iam get-user` から自動生成する |

## Usage

```bash
# 本番
cd terraform/aws/environment/prod
make terraform.tfvars
terraform init
terraform plan
terraform apply

# 開発サーバ
cd terraform/aws/environment/dev
make terraform.tfvars
terraform init
terraform plan
terraform apply

# 別アカウント SSM
cd terraform/aws/environment/secrets
# .envrc の AWS_PROFILE を実プロファイル名に書き換えてから
direnv allow
make terraform.tfvars
terraform init
terraform plan
terraform apply
# 初回 apply 後、コンソールか CLI で vault_password の値を実際の vault パスワードに上書き
aws ssm put-parameter --name /ansible/k3s_cluster/vault_password \
  --type SecureString --value '<実際の vault password>' --overwrite

# secret 取得例 (prod)
terraform output -raw juicefs_db_master_password
terraform output -raw juicefs_s3_iam_secret_access_key

# tfvars を消す
make clean
```

## Notes

- Lightsail インスタンスの user_data は inline で各 provisioner スクリプトが渡されます (`k3s_node_provisioner.sh` for prod, `dev_node_provisioner.sh` for dev)。
- 初回ブートストラップ手順 (22/TCP の一時開放 → tailscale / cloudflared 認証 → 再コメント) は [`../../ansible/README.md`](../../ansible/README.md) のセットアップ節を参照してください。
- JuiceFS の `juicefs format` / パスワードローテーション運用は [`../../docs/juicefs-setup-ja.md`](../../docs/juicefs-setup-ja.md) を参照してください。
- `module.lightsail_juicefs_db` のマスターパスワードは初回 apply 時に `random_password` で 32 文字ランダム生成され、その値が tfstate に残ります。秘匿性を高めたい場合は apply 直後に Lightsail コンソール (`aws lightsail update-relational-database --master-user-password`) で別パスワードにローテートしてください (`lifecycle.ignore_changes` で Terraform 側の差分にはなりません)。
