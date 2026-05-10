locals {
  name = "${var.project}_${var.purpose}"
}

resource "aws_lightsail_database" "this" {
  relational_database_name         = local.name
  availability_zone                = var.availability_zone
  relational_database_blueprint_id = var.blueprint_id
  relational_database_bundle_id    = var.bundle_id

  master_database_name = var.master_database_name
  master_username      = var.master_username
  master_password      = var.master_password

  apply_immediately            = var.apply_immediately
  publicly_accessible          = var.publicly_accessible
  backup_retention_enabled     = var.backup_retention_enabled
  preferred_backup_window      = var.preferred_backup_window
  preferred_maintenance_window = var.preferred_maintenance_window
  skip_final_snapshot          = var.skip_final_snapshot
  final_snapshot_name          = var.final_snapshot_name

  tags = {
    Name = local.name
  }

  lifecycle {
    ignore_changes = [master_password]
  }
}
