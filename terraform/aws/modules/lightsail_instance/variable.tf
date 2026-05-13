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

variable "user_data_url" {
  type        = string
  description = "URL to curl|bash from user_data. When null, https://akashisn.info/$${purpose}_lightsail.sh is used. Ignored if user_data is set."
  default     = null
}

variable "user_data" {
  type        = string
  description = "Raw user_data script. When set, this is passed inline and takes precedence over user_data_url."
  default     = null
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
