variable "project" {
  type = string
}

variable "cidr_block" {
  type    = string
  default = "10.226.0.0/16"
}

locals {
  az_suffix = ["a", "c"]
  subnet = {
    name_suffix = [
      "private-a",
      "private-c",
      "public-a",
      "public-c"
    ]
    availability_zones = [
      "ap-northeast-1a",
      "ap-northeast-1c",
      "ap-northeast-1a",
      "ap-northeast-1c"
    ]
    tags = [
      {},
      {},
      { "kubernetes.io/role/elb" = "1" },
      { "kubernetes.io/role/elb" = "1" }
    ]
  }
}
