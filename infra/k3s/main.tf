variable "proxmox_api_url" {
  type      = string
  sensitive = true
}

variable "proxmox_token_id" {
  type      = string
  sensitive = true
}
variable "proxmox_token_secret" {
  type      = string
  sensitive = true
}

terraform {
  required_providers {
    proxmox = {
      source  = "Telmate/proxmox"
      version = "2.9.14"
    }
  }
}

provider "proxmox" {
  pm_api_url          = var.proxmox_api_url
  pm_api_token_id     = var.proxmox_token_id
  pm_api_token_secret = var.proxmox_token_secret
}
