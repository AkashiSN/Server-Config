# output "vpc_id" {
#   value = module.vpc.vpc_id
# }

output "k3s_public_ipv4" {
  value = module.lightsail.k3s_public_ipv4
}

output "k3s_public_ipv6" {
  value = module.lightsail.k3s_public_ipv6
}
