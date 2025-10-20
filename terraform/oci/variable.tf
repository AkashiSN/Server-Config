variable "compartment_id" {
  type = string
}

variable "ssh_public_key" {
  type = string
}

variable "cloudflare_tunnel_token" {
  type      = string
  sensitive = true
}
