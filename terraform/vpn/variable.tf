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
  vpn = {
    vmid                 = 100
    template_vmid        = 9000
    memory               = 8192
    cores                = 4
    onboot               = true
    proxmox_node         = "pve-n100"
    proxmox_address      = "172.16.254.3"
    hostname             = "vpn-server"
    ipv4_address         = "172.16.254.100"
    ipv4_prefix          = "24"
    ipv4_default_gateway = "172.16.254.1"
    ipv6_address_token   = "::254:100"
    wg_if_ip             = "10.254.0.2"
    wg_peer_if_ip        = "10.254.0.1"
  }
}
