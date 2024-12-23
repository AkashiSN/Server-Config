variable "project" {
  type = string
}

variable "iam_user" {
  type      = string
  sensitive = true
}

variable "network" {
  type = object({
    service_cidr      = string
    remote_node_cidrs = list(string)
    remote_pod_cidrs  = list(string)
  })
}

variable "vpc" {
  type = object({
    subnet_ids = list(string)
    sg_ids     = list(string)
  })
}
