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
  k3s = {
    vmid                 = 115
    template_vmid        = 9001
    memory               = 8192
    cores                = 6
    onboot               = false
    proxmox_node         = "pve01"
    proxmox_address      = "172.16.254.5"
    hostname             = "k3s"
    ipv4_address         = "172.16.254.15"
    ipv4_prefix          = "24"
    ipv4_default_gateway = "172.16.254.1"
  }
}
