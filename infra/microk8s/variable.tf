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
  microk8s = {
    vmid                 = 115
    memory               = 20480
    cores                = 16
    onboot               = false
    proxmox_node         = "pve"
    proxmox_address      = "172.16.254.4"
    hostname             = "microk8s"
    ipv4_address         = "172.16.254.11/24"
    ipv4_default_gateway = "172.16.254.1"
  }
}
