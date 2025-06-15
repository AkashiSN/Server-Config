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
    vmid                  = 115
    template_vmid         = 9001
    memory                = 8192
    cores                 = 6
    onboot                = false
    proxmox_node          = "pve-i7"
    proxmox_address       = "172.16.254.6"
    hostname              = "k3s"
    ipv4_address          = "172.16.254.115"
    ipv4_prefix           = "24"
    ipv4_default_gateway  = "172.16.254.1"
    ipv6_address_token    = "::254:115"
    nas_interface_address = "172.16.255.3/24"
    nas_network_address   = "172.16.255.0/24"
    nas_network_gateway   = "172.16.255.1"
  }
}
