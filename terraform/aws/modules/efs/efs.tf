resource "aws_efs_file_system" "data" {
  creation_token = "${var.project}-efs"

  availability_zone_name = "ap-northeast-1a"

  throughput_mode  = "bursting"
  performance_mode = "generalPurpose"

  encrypted  = true
  kms_key_id = var.kms_key_arn

  lifecycle_policy {
    transition_to_ia = "AFTER_30_DAYS"
  }

  tags = {
    Name = "${var.project}-efs"
  }
}

resource "aws_efs_backup_policy" "data" {
  file_system_id = aws_efs_file_system.data.id

  backup_policy {
    status = "DISABLED"
  }
}

resource "aws_efs_mount_target" "data" {
  file_system_id  = aws_efs_file_system.data.id
  subnet_id       = var.vpc.subnet_id
  security_groups = [aws_security_group.efs.id]
}
