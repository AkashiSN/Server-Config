resource "aws_elasticache_user" "dify" {
  user_id       = "dify"
  user_name     = "dify"
  access_string = "on ~* +@all"
  engine        = "valkey"

  authentication_mode {
    type      = "password"
    passwords = [data.aws_ssm_parameter.elasticache_dify_password.value]
  }
}

resource "aws_elasticache_user_group" "dify" {
  user_group_id = "dify"
  engine        = "valkey"
  user_ids      = [aws_elasticache_user.dify.user_id]

  lifecycle {
    ignore_changes = [user_ids]
  }
}

# Elasticache serverless
# resource "aws_elasticache_serverless_cache" "dify" {
#   name        = "${var.project}-dify-cache"
#   description = "Valkey cache for Dify"

#   engine               = "valkey"
#   major_engine_version = "8"

#   subnet_ids         = var.vpc.private_subnet_ids
#   security_group_ids = [aws_security_group.elasticache.id]

#   daily_snapshot_time      = "11:00"
#   kms_key_id               = aws_kms_key.cache_key.arn
#   snapshot_retention_limit = 1

#   user_group_id = aws_elasticache_user_group.dify.user_group_id
# }

# Celery doesn't support cluster mode, so use normal elasticache instance.
# https://github.com/celery/celery/issues/2852
resource "aws_elasticache_subnet_group" "dify" {
  name        = "${var.project}-dify-cache-subnet"
  description = "Valkey cache for Dify"
  subnet_ids  = var.vpc.private_subnet_ids
}

resource "aws_elasticache_replication_group" "dify" {
  replication_group_id = "${var.project}-dify-cache"
  description          = "Valkey cache for Dify"

  engine               = "valkey"
  engine_version       = "8.0"
  parameter_group_name = "default.valkey8"

  port         = 6379
  cluster_mode = "disabled"
  node_type    = "cache.t4g.micro"

  subnet_group_name  = aws_elasticache_subnet_group.dify.name
  security_group_ids = [aws_security_group.elasticache.id]

  auto_minor_version_upgrade = true
  at_rest_encryption_enabled = true
  transit_encryption_enabled = true

  maintenance_window       = "sat:18:00-sat:19:00"
  snapshot_window          = "01:00-02:00"
  snapshot_retention_limit = 1


  user_group_ids = [aws_elasticache_user_group.dify.user_group_id]
}

locals {
  dify_cache_host = aws_elasticache_replication_group.dify.primary_endpoint_address
}
