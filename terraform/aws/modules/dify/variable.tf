variable "project" {
  type = string
}

# VPC
variable "vpc" {
  type = object({
    id                 = string
    private_subnet_ids = list(string)
    public_subnet_ids  = list(string)
  })
}

# ALB
variable "allowed_cidr_blocks" {
  type    = list(string)
  default = ["0.0.0.0/0"]
}

# ECS
# image version
variable "dify_version" {
  type = object({
    api     = string
    web     = string
    sandbox = string
  })
  default = {
    api     = "1.5.1"
    web     = "1.5.1"
    sandbox = "0.2.12"
  }
}

# resource
variable "dify_resource" {
  type = object({
    api = object({
      cpu           = number
      memory        = number
      desired_count = number
    })
    worker = object({
      cpu           = number
      memory        = number
      desired_count = number
    })
    web = object({
      cpu           = number
      memory        = number
      desired_count = number
    })
  })
  default = {
    api = {
      cpu           = 2048
      memory        = 2048
      desired_count = 1
    }
    worker = {
      cpu           = 2048
      memory        = 2048
      desired_count = 1
    }
    web = {
      cpu           = 2048
      memory        = 2048
      desired_count = 1
    }
  }
}
