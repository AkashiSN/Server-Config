variable "project" {
  type = string
}

variable "purpose" {
  type = string
}

variable "availability_zone" {
  type    = string
  default = "ap-northeast-1a"
}

variable "blueprint_id" {
  type    = string
  default = "ubuntu_24_04"
}

variable "bundle_id" {
  type = string
}

variable "ip_address_type" {
  type    = string
  default = "dualstack"
}

variable "user_data" {
  type        = string
  description = "Raw user_data script."
}

variable "disks" {
  type = map(object({
    size_in_gb = number
    disk_path  = string
  }))
  description = "Additional disks keyed by name suffix (`$${project}_$${purpose}-$${key}`). Pass {} for none"
}

variable "ports" {
  type = list(object({
    protocol   = string
    from_port  = number
    to_port    = number
    cidrs      = list(string)
    ipv6_cidrs = list(string)
  }))
  description = "Public ports to open. Pass [] for none"
}
