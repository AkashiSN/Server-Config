# Terraform / AWS (ap-northeast-1)

AWS リソースを 3 つの独立した Terraform プロジェクトに分割して管理します。各プロジェクトは `./environment/<env>` 配下にあり、tfstate も環境ごとに分離されています。共通のモジュールは `./modules/` 配下に置き、各環境から `../../modules/...` で参照します。

## 環境一覧

| 環境 | スコープ | Backend |
| --- | --- | --- |
| [`environment/prod`](./environment/prod/README.md) | 本番 k3s クラスタ (server×1 + agent×2) + JuiceFS 用 Lightsail PostgreSQL + S3 (juicefs / postgres-backup) | S3: `su-nishi` / `terraform/prod/ap-northeast-1.tfstate` |
| [`environment/dev`](./environment/dev/README.md) | リモート SSH 開発用 Lightsail 1 台 (`small_3_0`) | S3: `su-nishi` / `terraform/dev/ap-northeast-1.tfstate` |
| [`environment/secrets`](./environment/secrets/README.md) | 別 AWS アカウントの SSM Parameter Store に ansible-vault を put | S3: `su-nishi-tfstate` (別アカウント) / `terraform/secrets/ap-northeast-1.tfstate` |

詳細 (構成 / outputs / usage / notes) は各環境の README を参照してください。

## 共通モジュール

| モジュール | 役割 |
| --- | --- |
| [`./modules/lightsail_instance`](./modules/lightsail_instance/README.md) | 汎用 Lightsail インスタンス (Lightsail インスタンス / 任意の追加ディスク / Static IP / Key Pair / 公開ポート) を `purpose` 単位で構築。`scripts/k3s_node_provisioner.sh` (本番) と `scripts/dev_node_provisioner.sh` (開発) を同梱 |
| [`./modules/lightsail_database`](./modules/lightsail_database/README.md) | 汎用 Lightsail マネージド DB を `purpose` 単位で構築 |
| [`./modules/s3`](./modules/s3/README.md) | 任意用途の S3 バケットと専用 IAM ユーザ (送信元 IP 制限つき) |

## Backend bucket の事前作成

backend に使う以下の S3 バケットは Terraform 管理対象**外**で、事前に手動で作成・バージョニング有効化する必要があります。

| Bucket | アカウント | 用途 |
| --- | --- | --- |
| `su-nishi` | 自アカウント | prod / dev の tfstate |
| `su-nishi-tfstate` | 別アカウント | secrets の tfstate |

```bash
# 自アカウント側 (prod / dev 共用)
aws s3api create-bucket --bucket su-nishi --region ap-northeast-1 \
  --create-bucket-configuration LocationConstraint=ap-northeast-1
aws s3api put-bucket-versioning --bucket su-nishi \
  --versioning-configuration Status=Enabled

# 別アカウント側 (secrets 用、AWS_PROFILE を切り替えてから)
aws s3api create-bucket --bucket su-nishi-tfstate --region ap-northeast-1 \
  --create-bucket-configuration LocationConstraint=ap-northeast-1
aws s3api put-bucket-versioning --bucket su-nishi-tfstate \
  --versioning-configuration Status=Enabled
```
