# Database
resource "aws_db_subnet_group" "dify" {
  name        = "${var.project}-dify"
  description = "PostgreSQL for Dify"
  subnet_ids  = var.vpc.private_subnet_ids
}

resource "aws_rds_cluster" "dify" {
  cluster_identifier = "${var.project}-dify"

  engine         = "aurora-postgresql"
  engine_version = "16.6"
  port           = 5432

  db_subnet_group_name            = aws_db_subnet_group.dify.name
  db_cluster_parameter_group_name = "default.aurora-postgresql16"
  vpc_security_group_ids          = [aws_security_group.database.id]

  database_name               = "dify"
  master_username             = "dify"
  manage_master_user_password = true
  enable_http_endpoint        = true

  backup_retention_period  = 7
  delete_automated_backups = true

  preferred_backup_window      = "13:29-13:59"
  preferred_maintenance_window = "sat:18:00-sat:19:00"
  skip_final_snapshot          = true
  storage_encrypted            = true
  copy_tags_to_snapshot        = true

  serverlessv2_scaling_configuration {
    min_capacity = 2
    max_capacity = 4
  }

  lifecycle {
    ignore_changes = [engine_version]
  }
}

resource "aws_rds_cluster_instance" "dify" {
  identifier = "dify-instance-1"

  cluster_identifier = aws_rds_cluster.dify.cluster_identifier
  engine             = aws_rds_cluster.dify.engine
  engine_version     = aws_rds_cluster.dify.engine_version
  instance_class     = "db.serverless"

  auto_minor_version_upgrade = true
  promotion_tier             = 1

  db_parameter_group_name = "default.aurora-postgresql16"
  db_subnet_group_name    = aws_db_subnet_group.dify.name

  performance_insights_enabled          = true
  performance_insights_retention_period = 7
}
