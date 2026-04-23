# S3 Module

s3ql用のS3バケットと、そのバケット専用のIAMユーザを構築するTerraformモジュール。

## リソース構成

| リソース | 説明 |
|---|---|
| S3 Bucket | `${project}-${purpose}-bucket` |
| Encryption | AES256 (SSE-S3) |
| Public Access Block | すべてブロック |
| Lifecycle | 不完全なマルチパートアップロードを7日で中止 |
| IAM User | `${project}_${purpose}-user` |
| IAM Access Key | 上記ユーザの access key / secret key |
| IAM User Policy | `${project}_${purpose}-s3-policy` — 当該バケットに対する s3ql 必要操作のみ許可 (後述) |

## 入力変数

| 変数 | 説明 |
|---|---|
| `project` | プロジェクト名 |
| `purpose` | 用途識別子 (バケット名/ユーザ名に使われる) |
| `allowed_ip` | IAM ユーザのアクセスを許可する送信元 IPv4 アドレス (`/32` 固定)。Lightsail の static IP を想定 |

## 出力

| 出力 | 説明 |
|---|---|
| `bucket_name` | バケット名 |
| `bucket_arn` | バケット ARN |
| `bucket_domain_name` | バケットのリージョン別ドメイン名 |
| `iam_user_name` | 作成された IAM ユーザ名 |
| `iam_access_key_id` | Access Key ID |
| `iam_secret_access_key` | Secret Access Key (sensitive) |

## IAM ポリシー

IAM ユーザには以下の action のみが許可される。すべての statement に `aws:SourceIp` = `${allowed_ip}/32` の条件が付与されており、Lightsail のパブリック IP 以外からはアクセスできない。

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

### s3ql との対応

| s3ql 操作 | 必要な action |
|---|---|
| list (ディレクトリ列挙) | `s3:ListBucket` |
| lookup (HEAD object) | `s3:GetObject` |
| get | `s3:GetObject` |
| put (小オブジェクト) | `s3:PutObject` |
| put (マルチパート) | `s3:PutObject` + `s3:AbortMultipartUpload` + `s3:ListMultipartUploadParts` + `s3:ListBucketMultipartUploads` |
| delete | `s3:DeleteObject` |
| copy (rename) | source: `s3:GetObject` / dest: `s3:PutObject` |
| region 判定 | `s3:GetBucketLocation` |

SSE-S3 (AES256) のため KMS 権限は不要。バケットは事前に Terraform で作成されるため `s3:CreateBucket` も不要。バージョニングは使用しないため `s3:GetBucketVersioning` も不要。

## 備考

s3ql はブロック単位でオブジェクトを独自管理するため、S3 のバージョニングは有効化しない。

Secret Access Key は `terraform output -raw s3_${purpose}_iam_secret_access_key` で取得する。
