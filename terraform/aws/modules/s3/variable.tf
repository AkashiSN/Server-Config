variable "project" {
  type = string
}

variable "purpose" {
  type = string
}

variable "allowed_ip" {
  type        = string
  description = "Source IPv4 address (without CIDR) that is allowed to access the bucket via the IAM user"
}
