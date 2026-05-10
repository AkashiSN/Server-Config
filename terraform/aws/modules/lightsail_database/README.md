# Lightsail Database Module

AWS Lightsail マネージドデータベースを汎用的に 1 台構築する Terraform モジュール。`project` + `purpose` でリソース名を生成し、エンジン (PostgreSQL / MySQL) ・サイズ・バックアップ / メンテナンス窓・公開可否などを変数で指定する。

姉妹モジュールの [`lightsail_instance`](../lightsail_instance/README.md) と同じ命名規則・スタイルに揃えてある。

## リソース構成

| リソース | 説明 |
| --- | --- |
| `aws_lightsail_database.this` | Lightsail マネージド DB (`${project}_${purpose}`)。blueprint / bundle / 認証情報 / バックアップ / メンテ窓は変数で指定。`master_password` は `lifecycle.ignore_changes` で初回作成後は追従しない |

## 変数

| 変数 | 型 | デフォルト | 説明 |
| --- | --- | --- | --- |
| `project` | string | (必須) | リソース名のプレフィックス |
| `purpose` | string | (必須) | リソース名のサフィックス。`${project}_${purpose}` がそのまま `relational_database_name` と `Name` タグになる |
| `availability_zone` | string | `ap-northeast-1a` | DB を配置する AZ |
| `blueprint_id` | string | (必須) | DB エンジン (例: `postgres_16`, `mysql_8_0`)。一覧は `aws lightsail get-relational-database-blueprints` |
| `bundle_id` | string | (必須) | DB プラン (例: `micro_2_0`, `small_ha_2_0`)。`_ha_` が付くものは Multi-AZ 高可用構成。一覧は `aws lightsail get-relational-database-bundles` |
| `master_database_name` | string | (必須) | プロビジョン時に作成される初期 DB 名 |
| `master_username` | string | (必須) | マスターユーザ名。MySQL: 1-16 文字、PostgreSQL: 1-63 文字、英字始まり |
| `master_password` | string (sensitive) | (必須) | マスターパスワード。MySQL: 8-41 文字、PostgreSQL: 8-128 文字。`/`, `"`, `@`, スペース不可。**初回 apply 後はコンソールでローテートする運用 (後述)** |
| `apply_immediately` | bool | `false` | `true` で構成変更を即時適用 (短時間の停止あり)。`false` で次のメンテ窓まで遅延 |
| `publicly_accessible` | bool | `false` | `true` でインターネット公開エンドポイント発行。Lightsail には CIDR 制御がないため、公開する場合はパスワード強度のみが防御 |
| `backup_retention_enabled` | bool | `true` | 自動バックアップ (7 日保持) を有効化 |
| `preferred_backup_window` | string | `null` | UTC のバックアップ窓。`hh24:mi-hh24:mi` (例: `16:00-16:30`)。最低 30 分。`null` で AWS 任せ |
| `preferred_maintenance_window` | string | `null` | UTC のメンテ窓。`ddd:hh24:mi-ddd:hh24:mi` (例: `Tue:17:00-Tue:17:30`)。バックアップ窓と重複不可。`null` で AWS 任せ |
| `skip_final_snapshot` | bool | `true` | `true` で `terraform destroy` 時にスナップショットを取らずに削除 (homelab 向けデフォルト)。本番運用時は `false` + `final_snapshot_name` を推奨 |
| `final_snapshot_name` | string | `null` | `skip_final_snapshot=false` のときの最終スナップショット名 |

## 出力

| 出力 | 説明 |
| --- | --- |
| `endpoint` | 接続先ホスト名 (`master_endpoint_address`) |
| `port` | 接続先ポート (PostgreSQL: 5432, MySQL: 3306) |
| `ca_certificate_identifier` | TLS 接続検証用 CA 証明書識別子 |
| `engine` | エンジン (`postgres` / `mysql`) |
| `engine_version` | エンジンバージョン |
| `arn` | リソース ARN |

`master_username` / `master_password` は呼び出し側が指定値を持っているため出力しない。

## 呼び出し例

```hcl
module "lightsail_app_db" {
  source  = "./modules/lightsail_database"
  project = local.project
  purpose = "app-db"

  blueprint_id = "postgres_16"
  bundle_id    = "micro_2_0"

  master_database_name = "appdb"
  master_username      = "appuser"
  master_password      = var.app_db_initial_password # tfvars or env-var

  preferred_backup_window      = "16:00-16:30"
  preferred_maintenance_window = "Tue:17:00-Tue:17:30"
}
```

## `master_password` の取り扱い

Terraform の仕様上、リソース引数として渡した値は state file に必ず保存される (`sensitive = true` は CLI / log 出力での伏字化のみで state には平文で残る)。`aws_lightsail_database` は `master_password` が**作成時必須**かつ Write-Only Attributes (`master_password_wo`) も AWS provider 未対応のため、初回値の state 保存は回避できない。

本モジュールは多層防御で軽減する:

1. `sensitive = true` で plan / apply / output の表示を伏字化
2. `lifecycle { ignore_changes = [master_password] }` で初回作成後は Terraform が差分検出しない
3. backend は S3 + `encrypt = true` (provider.tf 側で設定済)

### 推奨運用フロー

```
1. 強いランダム文字列を master_password に渡して初回 terraform apply
2. AWS Lightsail コンソール / CLI で別パスワードに即座にローテート
   (例: aws lightsail update-relational-database \
          --relational-database-name <name> \
          --master-user-password <new-password> \
          --apply-immediately)
3. 以降のローテートはコンソール側のみ。Terraform 側は触らない
   (state に残るのは過去の使われていないパスワードになる)
```

## Lightsail マネージド DB の制約 (採用前に確認)

- **拡張機能の追加不可**: `shared_preload_libraries` を変更できないため、AWS が組み込んだもの以外の extension は使えない。`pgvector`, `vectorchord`, `pgvecto.rs` 等は **Lightsail マネージド DB では利用不可**。これらを必要とするワークロード (例: Immich の vector 検索) は本モジュール対象外で、`lightsail_instance` 上に PostgreSQL を自前構築するか K8s 上で動かす必要がある。
- **CIDR / SG レベルのアクセス制御なし**: ネットワーク制御は `publicly_accessible` の bool のみ。プライベート時は同 Lightsail アカウント内のリソースから接続、公開時は誰でも到達可能 (パスワードのみが防御)。
- **`blueprint_id` / `bundle_id` の変更は再作成**: エンジンメジャー版 / プラン変更は destroy + create を伴う。本番では `skip_final_snapshot=false` + 適切な `final_snapshot_name` を必ず指定する。

## 参考

- [aws_lightsail_database — Terraform Registry](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lightsail_database)
- [Create and manage relational databases in Lightsail (AWS Docs)](https://docs.aws.amazon.com/lightsail/latest/userguide/amazon-lightsail-databases.html)
- [High availability databases in Lightsail (AWS Docs)](https://docs.aws.amazon.com/lightsail/latest/userguide/amazon-lightsail-high-availability-databases.html)
