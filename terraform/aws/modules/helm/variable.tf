variable "email" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "eks_cluster_name" {
  type = string
}

variable "eks_cert_manager_sa_role_arn" {
  type = string
}

variable "eks_external_dns_sa_role_arn" {
  type = string
}

variable "host_zone_id" {
  type = string
}

variable "target_env" {
  type = string
}
