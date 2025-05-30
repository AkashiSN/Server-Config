variable "project" {
  type = string
}

variable "kms_key_arn" {
  type = string
}

variable "vpc" {
  type = object({
    id        = string
    cidr      = string
    subnet_id = string
  })
}
