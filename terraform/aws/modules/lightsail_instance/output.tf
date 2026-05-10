output "public_ipv4" {
  value = aws_lightsail_static_ip.this.ip_address
}

output "public_ipv6" {
  value = aws_lightsail_instance.this.ipv6_addresses[0]
}
