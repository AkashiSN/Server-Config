variable "project" {
  type = string
}

variable "homelab" {
  type = object({
    global_ip_address = string
  })
  sensitive = true
}
