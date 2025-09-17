output "k3s_public_ipv4" {
  value = aws_lightsail_static_ip.k3s.ip_address
}

output "k3s_public_ipv6" {
  value = aws_lightsail_instance.k3s.ipv6_addresses[0]
}
