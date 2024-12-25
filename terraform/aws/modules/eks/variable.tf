variable "project" {
  type = string
}

variable "iam_user" {
  type = string
}

variable "cluster_network" {
  type = object({
    service_cidr      = string
    remote_node_cidrs = list(string)
    remote_pod_cidrs  = list(string)
  })
}

variable "vpc" {
  type = object({
    id         = string
    subnet_ids = list(string)
  })
}
