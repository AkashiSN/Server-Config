# S3 Module

S3 バケットと、そのバケットに対する操作だけを許可した専用 IAM ユーザを構築する Terraform モジュール。
IAM ポリシーは s3ql のバックエンドとして必要な action のみを許可し、`allowed_ip` (`/32`) からのリクエストに限定する。

## リソース構成

| リソース | 説明 |
| --- | --- |
| `aws_s3_bucket.this` | バケット名 `${project}-${purpose}-bucket` |
| `aws_s3_bucket_server_side_encryption_configuration.this` | デフォルト暗号化 `AES256` (SSE-S3) |
| `aws_s3_bucket_public_access_block.this` | パブリックアクセスをすべてブロック (`block_public_acls` / `block_public_policy` / `ignore_public_acls` / `restrict_public_buckets`) |
| `aws_s3_bucket_versioning.this` | バージョニングを `Enabled` に設定 |
| `aws_s3_bucket_lifecycle_configuration.this` | 不完全マルチパートアップロードを 7 日後に中止 / 非現行バージョンを 7 日後に削除 / 孤立した削除マーカーを削除 |
| `aws_s3_bucket_policy.this` | 許可された IAM Principal 以外による `s3:DeleteObject` / `s3:DeleteObjectVersion` を `Deny` |
| `aws_iam_user.this` | IAM ユーザ `${project}_${purpose}-user` |
| `aws_iam_access_key.this` | 上記ユーザの access key / secret key |
| `aws_iam_user_policy.this` | `${project}_${purpose}-s3-policy` — 当該バケットに対する s3ql 必要操作のみ許可 |

## 変数

| 変数 | 型 | 説明 |
| --- | --- | --- |
| `project` | string | バケット名 / IAM ユーザ名のプレフィックス |
| `purpose` | string | 用途識別子 (バケット名 / IAM ユーザ名 / IAM ポリシー名に使われる) |
| `allowed_ip` | string | IAM ユーザのアクセスを許可する送信元 IPv4 (CIDR ではなく単一アドレス。内部で `/32` を付与する) |
| `admin_iam_user` | string | バケットポリシーで常に削除を許可する管理者 IAM ユーザ名 (ARN ではなくユーザ名。module 内部でアカウント ID と組み合わせて ARN を構築する) |
| `additional_delete_principals` | list(string) | バケットポリシーの削除許可リストに追加する IAM Principal ARN。デフォルトは空。module 自身が作成する IAM ユーザと `admin_iam_user` は常に許可されるため、それ以外を追加したい場合のみ指定する |

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

SSE-S3 (AES256) のため KMS 権限は不要。バケットは Terraform 側で作成するため `s3:CreateBucket` も不要。バケットでバージョニングを有効化しているが、s3ql はバージョン ID を意識せず通常の PUT / GET / DELETE のみで動作するため、`s3:GetBucketVersioning` や `s3:*ObjectVersion` 系の追加権限は不要。

## バケットポリシー

オブジェクト削除を「許可された IAM Principal 以外」から行えないよう、明示的な `Deny` を設定する。許可リストに含まれる Principal:

- module 自身が作成する IAM ユーザ (`aws_iam_user.this.arn`)
- `admin_iam_user` で指定された管理者 IAM ユーザ (`arn:aws:iam::${account_id}:user/${admin_iam_user}`)
- `additional_delete_principals` で渡された ARN

対象 action は `s3:DeleteObject` および `s3:DeleteObjectVersion`。バケット自体の削除 (`s3:DeleteBucket`) は terraform destroy で必要になるためポリシーには含めていない。

`aws:PrincipalArn` 条件で評価しているため、IAM ユーザだけでなく Assumed Role セッションの Principal ARN も指定可能。なお `aws:PrincipalArn` のマッチは literal 比較で、`arn:...:root` を指定しても同一アカウント内の IAM ユーザにはマッチしない (root ユーザ本人のみマッチする) ため、本 module では root ではなく管理者 IAM ユーザを明示的に許可している。

## 備考

- バージョニングを有効化しているため、s3ql によって上書き / 削除されたオブジェクトは旧バージョンとして一時的に残るが、ライフサイクルルールにより 7 日後に自動削除される (誤削除に対するリカバリ猶予を確保しつつコスト増を抑制)。
- 現行バージョンを期限切れにするルールは入れていないため、s3ql の現行データが lifecycle で消えることはない。
- Secret Access Key は `terraform output -raw <module 名>_iam_secret_access_key` で取得する。
