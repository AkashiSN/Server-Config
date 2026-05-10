output "file_system_id" {
  value = aws_efs_file_system.this.id
}

output "file_system_dns_name" {
  value = aws_efs_file_system.this.dns_name
}

output "mount_target_ip" {
  value = aws_efs_mount_target.this.ip_address
}
