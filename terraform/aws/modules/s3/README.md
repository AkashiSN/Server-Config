# S3 Module

S3 バケットと、そのバケットに対する操作だけを許可した専用 IAM ユーザを構築する Terraform モジュール。
IAM ポリシーは s3ql のバックエンドとして必要な action のみを許可し、`allowed_ip` (`/32`) からのリクエストに限定する。

## リソース構成

| リソース | 説明 |
| --- | --- |
| `aws_s3_bucket.this` | バケット名 `${project}-${purpose}-bucket` |
| `aws_s3_bucket_server_side_encryption_configuration.this` | デフォルト暗号化 `AES256` (SSE-S3) |
| `aws_s3_bucket_public_access_block.this` | パブリックアクセスをすべてブロック (`block_public_acls` / `block_public_policy` / `ignore_public_acls` / `restrict_public_buckets`) |
| `aws_s3_bucket_lifecycle_configuration.this` | 不完全なマルチパートアップロードを開始から 7 日後に中止 |
| `aws_iam_user.this` | IAM ユーザ `${project}_${purpose}-user` |
| `aws_iam_access_key.this` | 上記ユーザの access key / secret key |
| `aws_iam_user_policy.this` | `${project}_${purpose}-s3-policy` — 当該バケットに対する s3ql 必要操作のみ許可 |

## 変数

| 変数 | 型 | 説明 |
| --- | --- | --- |
| `project` | string | バケット名 / IAM ユーザ名のプレフィックス |
| `purpose` | string | 用途識別子 (バケット名 / IAM ユーザ名 / IAM ポリシー名に使われる) |
| `allowed_ip` | string | IAM ユーザのアクセスを許可する送信元 IPv4 (CIDR ではなく単一アドレス。内部で `/32` を付与する) |

## 出力

| 出力 | 説明 |
| --- | --- |
| `bucket_name` | バケット名 |
| `bucket_arn` | バケット ARN |
| `bucket_domain_name` | バケットのリージョン別ドメイン名 (`bucket_regional_domain_name`) |
| `iam_user_name` | 作成された IAM ユーザ名 |
| `iam_access_key_id` | Access Key ID |
| `iam_secret_access_key` | Secret Access Key (sensitive) |

## IAM ポリシー

すべての statement に `aws:SourceIp` = `${allowed_ip}/32` の `IpAddress` 条件が付与される。

### Bucket-level (`arn:aws:s3:::${bucket}`)

- `s3:ListBucket`
- `s3:GetBucketLocation`
- `s3:ListBucketMultipartUploads`

### Object-level (`arn:aws:s3:::${bucket}/*`)

- `s3:GetObject`
- `s3:PutObject`
- `s3:DeleteObject`
- `s3:AbortMultipartUpload`
- `s3:ListMultipartUploadParts`

### s3ql の操作との対応

| s3ql 操作 | 必要な action |
| --- | --- |
| list (ディレクトリ列挙) | `s3:ListBucket` |
| lookup (HEAD object) | `s3:GetObject` |
| get | `s3:GetObject` |
| put (小オブジェクト) | `s3:PutObject` |
| put (マルチパート) | `s3:PutObject` + `s3:AbortMultipartUpload` + `s3:ListMultipartUploadParts` + `s3:ListBucketMultipartUploads` |
| delete | `s3:DeleteObject` |
| copy (rename) | source: `s3:GetObject` / dest: `s3:PutObject` |
| region 判定 | `s3:GetBucketLocation` |

SSE-S3 (AES256) のため KMS 権限は不要。バケットは Terraform 側で作成するため `s3:CreateBucket` も不要。バージョニングは使わないため `s3:GetBucketVersioning` も不要。

## 備考

- s3ql はブロック単位でオブジェクトを独自管理するため、S3 のバージョニングは有効化しない。
- Secret Access Key は `terraform output -raw <module 名>_iam_secret_access_key` で取得する。
