resource "aws_lightsail_instance" "site_to_site_vpn" {
  name              = "${var.project}_s2s_vpn_instance"
  availability_zone = "ap-northeast-1a"
  blueprint_id      = "ubuntu_24_04"
  bundle_id         = "small_3_0"
  ip_address_type   = "dualstack"
  key_pair_name     = aws_lightsail_key_pair.main.name
  user_data         = file("${path.module}/template/s2s_vpn_userdata.sh")

  tags = {
    Name = "${var.project}_s2s_vpn_instance"
  }
}

resource "aws_lightsail_static_ip" "site_to_site_vpn" {
  name = "${var.project}_s2s_vpn_ip"
}

resource "aws_lightsail_static_ip_attachment" "site_to_site_vpn" {
  static_ip_name = aws_lightsail_static_ip.site_to_site_vpn.id
  instance_name  = aws_lightsail_instance.site_to_site_vpn.name
}

resource "aws_lightsail_instance_public_ports" "site_to_site_vpn" {
  instance_name = aws_lightsail_instance.site_to_site_vpn.name

  port_info {
    protocol   = "tcp"
    from_port  = 22
    to_port    = 22
    ipv6_cidrs = ["::/0"]
  }

  port_info {
    protocol   = "udp"
    from_port  = 51820
    to_port    = 51820
    ipv6_cidrs = ["::/0"]
  }
}
