resource "aws_lightsail_instance" "k3s" {
  name              = "${var.project}_k3s"
  availability_zone = "ap-northeast-1a"
  blueprint_id      = "ubuntu_24_04"
  bundle_id         = "xlarge_3_0"
  ip_address_type   = "dualstack"
  key_pair_name     = aws_lightsail_key_pair.main.name
  user_data         = "curl -fsSL https://akashisn.info/k3s_lightsail.sh | bash"

  tags = {
    Name = "${var.project}_k3s"
  }
}

resource "aws_lightsail_disk" "k3s_zfs" {
  name              = "${var.project}_k3s-zfs"
  size_in_gb        = 1024
  availability_zone = "ap-northeast-1a"
}

resource "aws_lightsail_disk_attachment" "k3s_zfs" {
  disk_name     = aws_lightsail_disk.k3s_zfs.name
  instance_name = aws_lightsail_instance.k3s.name
  disk_path     = "/dev/xvdf"
}

resource "aws_lightsail_static_ip" "k3s" {
  name = "${var.project}_k3s-ip"
}

resource "aws_lightsail_static_ip_attachment" "k3s" {
  static_ip_name = aws_lightsail_static_ip.k3s.id
  instance_name  = aws_lightsail_instance.k3s.name

  lifecycle {
    replace_triggered_by = [
      aws_lightsail_instance.k3s
    ]
  }
}

resource "aws_lightsail_instance_public_ports" "k3s" {
  instance_name = aws_lightsail_instance.k3s.name

  # port_info {
  #   protocol   = "tcp"
  #   from_port  = 22
  #   to_port    = 22
  #   cidrs      = ["0.0.0.0/0"]
  #   ipv6_cidrs = ["::/0"]
  # }

  port_info {
    protocol   = "udp"
    from_port  = 53
    to_port    = 53
    cidrs      = ["0.0.0.0/0"]
    ipv6_cidrs = ["::/0"]
  }

  port_info {
    protocol   = "tcp"
    from_port  = 443
    to_port    = 443
    cidrs      = ["0.0.0.0/0"]
    ipv6_cidrs = ["::/0"]
  }

  port_info {
    protocol   = "tcp"
    from_port  = 853
    to_port    = 853
    cidrs      = ["0.0.0.0/0"]
    ipv6_cidrs = ["::/0"]
  }

  port_info {
    protocol   = "udp"
    from_port  = 51820
    to_port    = 51820
    cidrs      = ["0.0.0.0/0"]
    ipv6_cidrs = ["::/0"]
  }

  lifecycle {
    replace_triggered_by = [
      aws_lightsail_instance.k3s
    ]
  }
}
