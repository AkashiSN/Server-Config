terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.69.0"
    }
  }
}

provider "proxmox" {
  endpoint = "https://172.16.254.4"
  username = var.proxmox.username
  password = var.proxmox.password
  insecure = true

  ssh {
    agent    = true
    username = "root"
  }
}

data "terraform_remote_state" "aws" {
  backend = "s3"

  config = {
    region         = "ap-northeast-1"
    bucket         = "su-nishi-bucket"
    key            = "terraform/ap-northeast-1.tfstate"
    dynamodb_table = "su-nishi-table"
  }
}
