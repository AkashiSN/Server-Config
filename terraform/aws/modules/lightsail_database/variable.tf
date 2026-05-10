variable "project" {
  type = string
}

variable "purpose" {
  type = string
}

variable "availability_zone" {
  type    = string
  default = "ap-northeast-1a"
}

variable "blueprint_id" {
  type        = string
  description = "Database engine blueprint (e.g., postgres_16, mysql_8_0). See: aws lightsail get-relational-database-blueprints"
}

variable "bundle_id" {
  type        = string
  description = "Database bundle (e.g., micro_2_0, small_ha_2_0). See: aws lightsail get-relational-database-bundles"
}

variable "master_database_name" {
  type        = string
  description = "Initial database name created at provisioning time"
}

variable "master_username" {
  type = string
}

variable "master_password" {
  type      = string
  sensitive = true
}

variable "apply_immediately" {
  type    = bool
  default = false
}

variable "publicly_accessible" {
  type    = bool
  default = false
}

variable "backup_retention_enabled" {
  type    = bool
  default = true
}

variable "preferred_backup_window" {
  type        = string
  description = "Daily backup window in UTC, format hh24:mi-hh24:mi. Null for AWS-chosen default"
  default     = null
}

variable "preferred_maintenance_window" {
  type        = string
  description = "Weekly maintenance window in UTC, format ddd:hh24:mi-ddd:hh24:mi. Null for AWS-chosen default"
  default     = null
}

variable "skip_final_snapshot" {
  type    = bool
  default = true
}

variable "final_snapshot_name" {
  type        = string
  description = "Name of final snapshot when destroying. Required if skip_final_snapshot=false"
  default     = null
}
