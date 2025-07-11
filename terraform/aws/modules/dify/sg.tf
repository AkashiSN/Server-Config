# Redis
resource "aws_security_group" "redis" {
  name        = "${var.project}-dify-redis"
  description = "Redis for Dify"
  vpc_id      = var.vpc.id

  tags = {
    Name = "${var.project}-dify-redis"
  }
}

# Database
resource "aws_security_group" "database" {
  name        = "${var.project}-dify-db"
  description = "PostgreSQL for Dify"
  vpc_id      = var.vpc.id

  tags = {
    Name = "${var.project}-dify-db"
  }
}

# API
resource "aws_security_group" "api" {
  name        = "${var.project}-dify-api"
  description = "Dify API"
  vpc_id      = var.vpc.id

  tags = {
    Name = "${var.project}-dify-api"
  }
}

# Worker
resource "aws_security_group" "worker" {
  name        = "${var.project}-dify-worker"
  description = "Dify Worker"
  vpc_id      = var.vpc.id

  tags = {
    Name = "${var.project}-dify-worker"
  }
}

# Web
resource "aws_security_group" "web" {
  name        = "${var.project}-dify-web"
  description = "Dify Web"
  vpc_id      = var.vpc.id

  tags = {
    Name = "${var.project}-dify-web"
  }
}

# ALB
resource "aws_security_group" "alb" {
  name        = "${var.project}-dify-alb"
  description = "ALB (Reverse Proxy) for Dify"
  vpc_id      = var.vpc.id

  tags = {
    Name = "${var.project}-dify-alb"
  }
}

## Security group rule
# Database
# S3 バックアップなどでインターネットへのアクセスが必要な場合は egress を追加する。
# VPC Endpoint や Managed Prefix List を使ってインターネットへのアクセスを制限するのがベター。
resource "aws_security_group_rule" "database_to_internet" {
  security_group_id = aws_security_group.database.id
  type              = "egress"
  description       = "Internet"
  protocol          = "all"
  from_port         = 0
  to_port           = 0
  cidr_blocks       = ["0.0.0.0/0"]
}

# API
# TODO: 公式では SSRF 対策のために Forward Proxy として squid をプロビジョニングしているが、
# 本構成では SSRF 対策の Forward Proxy は省略している。必要な場合は squid のタスクを用意したり、Firewall Manager などを利用する。
resource "aws_security_group_rule" "api_to_internet" {
  security_group_id = aws_security_group.api.id
  type              = "egress"
  description       = "Internet"
  protocol          = "all"
  from_port         = 0
  to_port           = 0
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "alb_to_api" {
  security_group_id        = aws_security_group.api.id
  type                     = "ingress"
  description              = "ALB to API"
  protocol                 = "tcp"
  from_port                = 5001
  to_port                  = 5001
  source_security_group_id = aws_security_group.alb.id
}

resource "aws_security_group_rule" "api_to_database" {
  security_group_id        = aws_security_group.database.id
  type                     = "ingress"
  description              = "API to Database"
  protocol                 = "tcp"
  from_port                = 5432
  to_port                  = 5432
  source_security_group_id = aws_security_group.api.id
}

resource "aws_security_group_rule" "api_to_redis" {
  security_group_id        = aws_security_group.redis.id
  type                     = "ingress"
  description              = "API to Redis"
  protocol                 = "tcp"
  from_port                = 6379
  to_port                  = 6379
  source_security_group_id = aws_security_group.api.id
}

# Worker
resource "aws_security_group_rule" "worker_to_internet" {
  security_group_id = aws_security_group.worker.id
  type              = "egress"
  description       = "Internet"
  protocol          = "all"
  from_port         = 0
  to_port           = 0
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "worker_to_database" {
  security_group_id        = aws_security_group.database.id
  type                     = "ingress"
  description              = "Worker to Database"
  protocol                 = "tcp"
  from_port                = 5432
  to_port                  = 5432
  source_security_group_id = aws_security_group.worker.id
}

resource "aws_security_group_rule" "worker_to_redis" {
  security_group_id        = aws_security_group.redis.id
  type                     = "ingress"
  description              = "Worker to Redis"
  protocol                 = "tcp"
  from_port                = 6379
  to_port                  = 6379
  source_security_group_id = aws_security_group.worker.id
}

# Web
resource "aws_security_group_rule" "web_to_internet" {
  security_group_id = aws_security_group.web.id
  type              = "egress"
  description       = "Internet"
  protocol          = "all"
  from_port         = 0
  to_port           = 0
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "alb_to_web" {
  security_group_id        = aws_security_group.web.id
  type                     = "ingress"
  description              = "ALB to Web"
  protocol                 = "tcp"
  from_port                = 3000
  to_port                  = 3000
  source_security_group_id = aws_security_group.alb.id
}

# ALB
resource "aws_security_group_rule" "alb_to_targetgroup" {
  security_group_id = aws_security_group.alb.id
  type              = "egress"
  description       = "ALB to TargetGroup"
  protocol          = "all"
  from_port         = 0
  to_port           = 0
  cidr_blocks       = [data.aws_vpc.this.cidr_block]
}

resource "aws_security_group_rule" "http_from_internet" {
  security_group_id = aws_security_group.alb.id
  type              = "ingress"
  description       = "HTTP from Internet"
  protocol          = "tcp"
  from_port         = 80
  to_port           = 80
  cidr_blocks       = var.allowed_cidr_blocks
}
