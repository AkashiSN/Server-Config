resource "aws_lightsail_instance" "k3s" {
  name              = "${var.project}-k3s"
  availability_zone = "ap-northeast-1a"
  blueprint_id      = "ubuntu_24_04"
  bundle_id         = "medium_3_0"
  ip_address_type   = "dualstack"
  key_pair_name     = aws_lightsail_key_pair.main.name
  user_data         = <<EOF
curl https://github.com/AkashiSN.keys > /home/ubuntu/.ssh/authorized_keys
sed -i 's/^TrustedUserCAKeys/# TrustedUserCAKeys/g' /etc/ssh/sshd_config
service ssh restart
EOF

  tags = {
    Name = "${var.project}-k3s"
  }
}

resource "aws_lightsail_static_ip" "k3s" {
  name = "${var.project}-k3s-ip"
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

  port_info {
    protocol   = "tcp"
    from_port  = 22
    to_port    = 22
    cidrs      = ["0.0.0.0/0"]
    ipv6_cidrs = ["::/0"]
  }

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

  lifecycle {
    replace_triggered_by = [
      aws_lightsail_instance.k3s
    ]
  }
}

# Wait for cloud-init completed
resource "terraform_data" "k3s_wait_for_clout_init" {
  depends_on = [aws_lightsail_instance_public_ports.k3s]
  triggers_replace = [
    aws_lightsail_instance.k3s.arn
  ]

  provisioner "remote-exec" {
    connection {
      type  = "ssh"
      user  = "ubuntu"
      agent = true
      host  = aws_lightsail_static_ip.k3s.ip_address
    }
    inline = ["sudo cloud-init status --wait"]
  }
}

resource "local_file" "k3s_provisioner" {
  depends_on = [terraform_data.k3s_wait_for_clout_init]
  filename   = "${path.module}/.tmp/k3s_provisioner.sh"
  content = templatefile("${path.module}/template/k3s_provisioner.sh.tftpl", {
    hostname = "k3s-lightsail"
  })
}

resource "terraform_data" "k3s_provisioner" {
  provisioner "remote-exec" {
    connection {
      type  = "ssh"
      user  = "ubuntu"
      agent = true
      host  = aws_lightsail_static_ip.k3s.ip_address
    }
    script = local_file.k3s_provisioner.filename
  }
}

resource "terraform_data" "k3s_reboot" {
  depends_on = [terraform_data.k3s_provisioner]

  provisioner "remote-exec" {
    connection {
      type  = "ssh"
      user  = "ubuntu"
      agent = true
      host  = aws_lightsail_static_ip.k3s.ip_address
    }
    inline = ["sudo shutdown -r +0"]
  }
}
