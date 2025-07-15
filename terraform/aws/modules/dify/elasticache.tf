
# Redis serverless
resource "aws_elasticache_serverless_cache" "dify" {
  name        = "${var.project}-dify-cache"
  description = "Redis cache for Dify"

  engine               = "redis"
  major_engine_version = "7"

  subnet_ids         = var.vpc.private_subnet_ids
  security_group_ids = [aws_security_group.redis.id]

  daily_snapshot_time      = "11:00"
  kms_key_id               = aws_kms_key.cache_key.arn
  snapshot_retention_limit = 1
}

locals {
  redis_serverless_host = aws_elasticache_serverless_cache.dify.endpoint[0].address
  redis_serverless_port = aws_elasticache_serverless_cache.dify.endpoint[0].port
}
