variable "proxmox" {
  type = object({
    endpoint = string
    username = string
    password = string
  })
  sensitive = true
}

variable "userdata" {
  type = object({
    user_name       = string
    hashed_password = string # mkpasswd --method=yescrypt (via whois)
    github_id       = string
  })
  sensitive = true
}

locals {
  vpn_server = {
    vmid                 = 110
    template_vmid        = 9000
    memory               = 16384
    cores                = 6
    onboot               = true
    proxmox_node         = "pve"
    proxmox_address      = "172.16.254.4"
    hostname             = "vpn-server"
    ipv4_address         = "172.16.254.10"
    ipv4_prefix          = "24"
    ipv4_default_gateway = "172.16.254.1"
    ipv6_address_token   = "::254:10"
  }
}
