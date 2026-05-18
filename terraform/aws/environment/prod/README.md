# Terraform / AWS / prod (ap-northeast-1)

本番 k3s クラスタ (server×1 + agent×2) + JuiceFS 用 Lightsail PostgreSQL + S3 (juicefs / postgres-backup) を管理する Terraform プロジェクト。

| 項目 | 値 |
| --- | --- |
| Backend | S3: `su-nishi-tfstate` / `terraform/prod/ap-northeast-1.tfstate` |
| プロファイル | 自アカウントの default プロファイル |
| `terraform` required_version | `1.15.3"` |
| `hashicorp/aws` | `6.45.0` |
| `hashicorp/random` | `3.9.0` |
| Region | `ap-northeast-1` |
| Default tags | `CreatedBy = var.iam_user` |

## 構成

- `local.project = "su-nishi"` (`locals.tf`) — リソース名のプレフィックス。
- `local.k3s_cluster_nodes` (`locals.tf`) — server (`medium_3_0`) / agent-0 / agent-1 (`xlarge_3_0`) の 3 ノード定義。`for_each` で `module.k3s_cluster["<key>"]` として展開される。追加ディスクは作らず、bundle root SSD (medium=80GB / xlarge=320GB) で k3s ローカル領域と JuiceFS キャッシュを賄う。永続データは JuiceFS (S3 backed) に逃がす想定。
- `module.k3s_cluster` の `user_data` には [`../../modules/lightsail_instance/scripts/k3s_node_provisioner.sh`](../../modules/lightsail_instance/scripts/k3s_node_provisioner.sh) を inline で渡す。GitHub 公開鍵による SSH authorized_keys 上書き / cloudflared / tailscale のインストールまでで、k3s 本体は ansible (`../../../../ansible/setup-k3s-cluster.yml`) でセットアップする。
- `ports` で 6443 / 8472 / 10250 を public 開放してはいけない (kubectl は Tailscale 経由で `--tls-san` に登録した DNS / IP からのみ繋ぐ)。443 は k3s 同梱の Traefik (Gateway API provider 有効化) を載せる agent ノードのみ (80 は受けない)。41641 は tailscale 用に全ノードで開ける。22/TCP は初回ブートストラップ時のみ一時的にアンコメントして apply → tailscale / cloudflared 認証 → 再コメントして apply で塞ぐ。
- `module.lightsail_juicefs_db` で JuiceFS のメタデータエンジン用 Lightsail PostgreSQL 18 (`micro_2_0` プラン、single-AZ) を作成する。マスターパスワードは `random_password.juicefs_db` で生成し、output 経由でのみ取得できる。`lifecycle.ignore_changes = [master_password]` のため、初回 apply 後に Lightsail コンソールでローテートしても Terraform 側で drift にならない。
- `module.juicefs_s3` で JuiceFS のオブジェクトストレージ用 S3 バケット (`su-nishi-juicefs`) と、k3s クラスタ各ノードの static IPv4 からのみアクセス可能な IAM ユーザを作成する。
- `module.postgres_backup_s3` で Immich Postgres (将来的には Nextcloud Postgres も) の WAL-G バックアップ用 S3 バケット (`su-nishi-postgres-backup`) を作成する。`noncurrent_days = 35` で WAL-G 側の `wal-g delete retain FULL 4` と整合させる。
- 実際に JuiceFS を `juicefs format` / `juicefs mount` する手順は [`../../../../docs/juicefs-setup-ja.md`](../../../../docs/juicefs-setup-ja.md) を、WAL-G の運用手順は [`../../../../docs/postgres-walg-backup-ja.md`](../../../../docs/postgres-walg-backup-ja.md) を参照。

## Outputs

| Output | 内容 |
| --- | --- |
| `k3s_cluster_server_public_ipv4` / `k3s_cluster_server_private_ipv4` | server ノードの Lightsail static / private IPv4 |
| `k3s_cluster_agent_public_ipv4` / `k3s_cluster_agent_private_ipv4` | agent ノードの IPv4 (list) |
| `juicefs_db_endpoint` / `juicefs_db_port` / `juicefs_db_engine` / `juicefs_db_engine_version` | JuiceFS メタデータ DB の接続情報 |
| `juicefs_db_master_username` / `juicefs_db_master_password` | JuiceFS DB の認証情報 (password は sensitive) |
| `juicefs_s3_bucket_name` / `juicefs_s3_bucket_arn` / `juicefs_s3_iam_user_name` / `juicefs_s3_iam_access_key_id` / `juicefs_s3_iam_secret_access_key` | JuiceFS 用 S3 と IAM (secret は sensitive) |
| `postgres_backup_s3_*` | Postgres バックアップ用 S3 と IAM (上記と同形、secret は sensitive) |

これらの値は ansible 側の `group_vars/k3s_cluster/vault.yml` に登録して JuiceFS CSI Driver / WAL-G sidecar から利用します。

## Variables

| 変数 | 型 | 説明 |
| --- | --- | --- |
| `iam_user` | string | デフォルトタグ `CreatedBy` に入れる IAM ユーザ名。`make terraform.tfvars` で `aws iam get-user` から自動生成する |

## Usage

```bash
cd terraform/aws/environment/prod
make terraform.tfvars
terraform init
terraform plan
terraform apply

# secret 取得例
terraform output -raw juicefs_db_master_password
terraform output -raw juicefs_s3_iam_secret_access_key

# tfvars を消す
make clean
```

## Notes

- Lightsail インスタンスの user_data は inline で [`../../modules/lightsail_instance/scripts/k3s_node_provisioner.sh`](../../modules/lightsail_instance/scripts/k3s_node_provisioner.sh) が渡されます。
- 初回ブートストラップ手順 (22/TCP の一時開放 → tailscale / cloudflared 認証 → 再コメント) は [`../../../../ansible/README.md`](../../../../ansible/README.md) のセットアップ節を参照してください。
- JuiceFS の `juicefs format` / パスワードローテーション運用は [`../../../../docs/juicefs-setup-ja.md`](../../../../docs/juicefs-setup-ja.md) を参照してください。
- `module.lightsail_juicefs_db` のマスターパスワードは初回 apply 時に `random_password` で 32 文字ランダム生成され、その値が tfstate に残ります。秘匿性を高めたい場合は apply 直後に Lightsail コンソール (`aws lightsail update-relational-database --master-user-password`) で別パスワードにローテートしてください (`lifecycle.ignore_changes` で Terraform 側の差分にはなりません)。
- backend に使う `su-nishi` バケットは Terraform 管理対象**外**で、事前に手動で作成・バージョニング有効化する必要があります (詳細は [`../../README.md`](../../README.md))。
