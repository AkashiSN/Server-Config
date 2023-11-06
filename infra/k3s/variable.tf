variable "userdata" {
  type = object({
    user_name       = string
    hashed_password = string # mkpasswd --method=yescrypt (via whois)
  })
  sensitive = true
}

variable "github_id" {
  type    = string
  default = "AkashiSN"
}

locals {
  k3s = {
    vmid                 = 115
    memory               = 16384
    cores                = 16
    onboot               = false
    proxmox_node         = "pve"
    proxmox_address      = "172.16.254.4"
    hostname             = "k3s"
    ipv4_address         = "172.16.254.15/24"
    ipv4_default_gateway = "172.16.254.1"
  }
}
