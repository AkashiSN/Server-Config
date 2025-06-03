resource "aws_lightsail_instance" "main" {
  name              = "${var.project}_instance"
  availability_zone = "ap-northeast-1a"
  blueprint_id      = "ubuntu_24_04"
  bundle_id         = "small_3_0"
  ip_address_type   = "dualstack"
  key_pair_name     = aws_lightsail_key_pair.main.name

  tags = {
    Name = "${var.project}_instance"
  }
}

resource "aws_lightsail_static_ip" "main" {
  name = "${var.project}_static-ip"
}

resource "aws_lightsail_static_ip_attachment" "main" {
  static_ip_name = aws_lightsail_static_ip.main.id
  instance_name  = aws_lightsail_instance.main.name
}

resource "aws_lightsail_instance_public_ports" "main" {
  instance_name = aws_lightsail_instance.main.name

  port_info {
    protocol  = "tcp"
    from_port = 22
    to_port   = 22
    cidrs     = ["0.0.0.0/0"]
  }
}
