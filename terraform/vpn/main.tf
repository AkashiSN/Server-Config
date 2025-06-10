terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.78.1"
    }
  }
}

provider "proxmox" {
  endpoint = "https://172.16.254.3"
  username = var.proxmox.username
  password = var.proxmox.password
  insecure = true

  ssh {
    agent    = true
    username = "root"
  }
}
