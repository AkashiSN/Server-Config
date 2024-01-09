terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.43.0"
    }
  }
}

provider "proxmox" {
  endpoint = var.proxmox.endpoint
  username = var.proxmox.user
  password = var.proxmox.pass

  ssh {
    agent    = true
    username = "root"
  }
}
