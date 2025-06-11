output "s2s_vpn_private_ipv4" {
  value = aws_lightsail_instance.site_to_site_vpn.private_ip_address
}

output "s2s_vpn_public_ipv4" {
  value = aws_lightsail_static_ip.site_to_site_vpn.ip_address
}

output "s2s_vpn_public_ipv6" {
  value = aws_lightsail_instance.site_to_site_vpn.ipv6_addresses[0]
}

output "s2s_vpn_wg_pubkey" {
  value = data.external.wg_pubkey.result.content
}
