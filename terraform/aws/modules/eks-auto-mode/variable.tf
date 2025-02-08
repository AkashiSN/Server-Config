variable "project" {
  type = string
}

variable "homelab" {
  type = object({
    global_ip_address = string
  })
}

variable "iam_user" {
  type = string
}

variable "vpc" {
  type = object({
    id         = string
    subnet_ids = list(string)
  })
}
