# Elasticache
resource "aws_kms_key" "cache_key" {
  description = "Key for ElastCache"
}
