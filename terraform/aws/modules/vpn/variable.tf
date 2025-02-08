variable "project" {
  type = string
}

variable "homelab" {
  type = object({
    global_ip_address = string
  })
  sensitive = true
}

variable "vpc" {
  type = object({
    id = string
    route_table_id = object({
      main      = string
      private_a = string
      private_c = string
    })
  })
}
