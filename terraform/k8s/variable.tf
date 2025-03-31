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
  k8s_version = 132
  base_number = local.k8s_version + 3
  k8s_control_plane = {
    vmid                 = local.base_number
    template_vmid        = 9001
    memory               = 16384
    cores                = 6
    onboot               = true
    proxmox_node         = "pve01"
    proxmox_address      = "172.16.254.5"
    hostname             = "k8s-v${local.k8s_version}-control-plane"
    ipv4_address         = "172.16.254.${local.base_number}"
    ipv4_prefix          = "24"
    ipv4_default_gateway = "172.16.254.1"
    ipv6_address_token   = "::254:${local.base_number}"
  }
  worker_node_01 = {
    vmid                  = local.base_number + 1
    template_vmid         = 9000
    memory                = 32768
    cores                 = 16
    onboot                = true
    proxmox_node          = "pve"
    proxmox_address       = "172.16.254.4"
    hostname              = "k8s-v${local.k8s_version}-worker-node-01"
    ipv4_address          = "172.16.254.${local.base_number + 1}"
    ipv4_prefix           = "24"
    ipv4_default_gateway  = "172.16.254.1"
    ipv6_address_token    = "::254:${local.base_number + 1}"
    nas_interface_address = "172.16.255.2/24"
    nas_network_address   = "172.16.255.0/24"
    nas_network_gateway   = "172.16.255.1"
  }
  worker_node_02 = {
    vmid                  = local.base_number + 2
    template_vmid         = 9002
    memory                = 49152
    cores                 = 8
    onboot                = true
    proxmox_node          = "pve02"
    proxmox_address       = "172.16.254.6"
    hostname              = "k8s-v${local.k8s_version}-worker-node-02"
    ipv4_address          = "172.16.254.${local.base_number + 2}"
    ipv4_prefix           = "24"
    ipv4_default_gateway  = "172.16.254.1"
    ipv6_address_token    = "::254:${local.base_number + 2}"
    nas_interface_address = "172.16.255.3/24"
    nas_network_address   = "172.16.255.0/24"
    nas_network_gateway   = "172.16.255.1"
  }
}
