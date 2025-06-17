resource "aws_lightsail_instance" "site_to_site_vpn" {
  name              = "${var.project}_s2s_vpn_instance"
  availability_zone = "ap-northeast-1a"
  blueprint_id      = "ubuntu_24_04"
  bundle_id         = "small_3_0"
  ip_address_type   = "dualstack"
  key_pair_name     = aws_lightsail_key_pair.main.name
  user_data         = <<EOF
curl https://github.com/AkashiSN.keys > /home/ubuntu/.ssh/authorized_keys
sed -i 's/^TrustedUserCAKeys/# TrustedUserCAKeys/g' /etc/ssh/sshd_config
service ssh restart
EOF

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

  lifecycle {
    replace_triggered_by = [
      aws_lightsail_instance.site_to_site_vpn
    ]
  }
}

resource "aws_lightsail_instance_public_ports" "site_to_site_vpn" {
  instance_name = aws_lightsail_instance.site_to_site_vpn.name

  port_info {
    protocol   = "tcp"
    from_port  = 22
    to_port    = 22
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
    protocol   = "udp"
    from_port  = 51820
    to_port    = 51820
    cidrs      = ["0.0.0.0/0"]
    ipv6_cidrs = ["::/0"]
  }

  lifecycle {
    replace_triggered_by = [
      aws_lightsail_instance.site_to_site_vpn
    ]
  }
}

# Wait for cloud-init completed
resource "terraform_data" "wait_for_clout_init" {
  depends_on = [aws_lightsail_instance_public_ports.site_to_site_vpn]
  triggers_replace = [
    aws_lightsail_instance.site_to_site_vpn.arn
  ]

  provisioner "remote-exec" {
    connection {
      type  = "ssh"
      user  = "ubuntu"
      agent = true
      host  = aws_lightsail_static_ip.site_to_site_vpn.ip_address
    }
    inline = ["sudo cloud-init status --wait"]
  }
}

resource "local_file" "site_to_site_vpn_provisioner" {
  depends_on = [terraform_data.wait_for_clout_init]
  filename   = "${path.module}/.tmp/s2s_vpn_provisioner.sh"
  content = templatefile("${path.module}/template/s2s_vpn_provisioner.sh.tftpl", {
    hostname            = "s2s-vpn-lightsail"
    wireguard_server_ip = "10.254.0.1"
  })
}

resource "terraform_data" "site_to_site_vpn_provisioner" {
  provisioner "remote-exec" {
    connection {
      type  = "ssh"
      user  = "ubuntu"
      agent = true
      host  = aws_lightsail_static_ip.site_to_site_vpn.ip_address
    }
    script = local_file.site_to_site_vpn_provisioner.filename
  }
}

data "external" "wg_pubkey" {
  depends_on = [terraform_data.site_to_site_vpn_provisioner]

  program = ["bash", "${path.module}/scripts/read_file.sh"]

  query = {
    host = aws_lightsail_static_ip.site_to_site_vpn.ip_address
    user = "ubuntu"
    key  = "~/.ssh/gpg.pub"
    path = "/etc/wireguard/public.key"
  }
}

resource "terraform_data" "reboot" {
  depends_on = [data.external.wg_pubkey]
  triggers_replace = [
    data.external.wg_pubkey.result.content
  ]

  provisioner "remote-exec" {
    connection {
      type  = "ssh"
      user  = "ubuntu"
      agent = true
      host  = aws_lightsail_static_ip.site_to_site_vpn.ip_address
    }
    inline = ["sudo shutdown -r +0"]
  }
}
