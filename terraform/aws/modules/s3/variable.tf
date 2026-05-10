variable "project" {
  type = string
}

variable "purpose" {
  type = string
}

variable "allowed_ips" {
  type        = list(string)
  description = "Source IPv4 address (with CIDR) that is allowed to access the bucket via the IAM user"
}

variable "admin_iam_user" {
  type        = string
  description = "IAM user name of the admin (always allowed to delete objects via the bucket policy)"
}

variable "additional_delete_principals" {
  type        = list(string)
  description = "Additional IAM principal ARNs allowed to delete objects (the module's own IAM user and admin_iam_user are always allowed)"
  default     = []
}
