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
  k8s_control_plane = {
    vmid                 = 120
    template_vmid        = 9001
    memory               = 16384
    cores                = 6
    onboot               = true
    proxmox_node         = "pve01"
    proxmox_address      = "172.16.254.5"
    hostname             = "k8s-control-plane"
    ipv4_address         = "172.16.254.20"
    ipv4_prefix          = "24"
    ipv4_default_gateway = "172.16.254.1"
    ipv6_address_token   = "::254:20"
  }
  worker_node_01 = {
    vmid                  = 125
    template_vmid         = 9000
    memory                = 32768
    cores                 = 16
    onboot                = true
    proxmox_node          = "pve"
    proxmox_address       = "172.16.254.4"
    hostname              = "worker-node-01"
    ipv4_address          = "172.16.254.25"
    ipv4_prefix           = "24"
    ipv4_default_gateway  = "172.16.254.1"
    ipv6_address_token    = "::254:25"
    nas_interface_address = "172.16.255.2/24"
    nas_network_address   = "172.16.255.0/24"
    nas_network_gateway   = "172.16.255.1"
  }
  worker_node_02 = {
    vmid                  = 126
    template_vmid         = 9002
    memory                = 55296
    cores                 = 8
    onboot                = true
    proxmox_node          = "pve02"
    proxmox_address       = "172.16.254.6"
    hostname              = "worker-node-02"
    ipv4_address          = "172.16.254.26"
    ipv4_prefix           = "24"
    ipv4_default_gateway  = "172.16.254.1"
    ipv6_address_token    = "::254:26"
    nas_interface_address = "172.16.255.3/24"
    nas_network_address   = "172.16.255.0/24"
    nas_network_gateway   = "172.16.255.1"
  }
}
