variable "project" {
  type = string
}

variable "availability_zone" {
  type    = string
  default = "ap-northeast-1a"
}

variable "lightsail_cidr" {
  type        = string
  description = "Lightsail VPC CIDR (ap-northeast-1 のデフォルトは 172.26.0.0/16)"
  default     = "172.26.0.0/16"
}
