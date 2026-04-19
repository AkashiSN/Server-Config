# S3 Module

s3ql用のS3バケットを構築するTerraformモジュール。

## リソース構成

| リソース | 説明 |
|---|---|
| S3 Bucket | `${project}-${purpose}-bucket` |
| Encryption | AES256 (SSE-S3) |
| Public Access Block | すべてブロック |
| Lifecycle | 不完全なマルチパートアップロードを7日で中止 |

## 備考

s3ql はブロック単位でオブジェクトを独自管理するため、S3 のバージョニングは有効化しない。
