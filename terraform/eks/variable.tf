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
  k8s_version = 131
  hybrid_node_01 = {
    vmid                 = local.k8s_version + 50
    template_vmid        = 9000
    memory               = 32768
    cores                = 16
    onboot               = true
    proxmox_node         = "pve"
    proxmox_address      = "172.16.254.4"
    hostname             = "eks-v${local.k8s_version}-hybrid-node-01"
    ipv4_address         = "172.16.254.${local.k8s_version + 50}"
    ipv4_prefix          = "24"
    ipv4_default_gateway = "172.16.254.1"
  }
}
