terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.50.0"
    }
  }
}

provider "proxmox" {
  endpoint = var.proxmox.endpoint
  username = var.proxmox.username
  password = var.proxmox.password

  ssh {
    agent    = true
    username = "root"
  }
}
