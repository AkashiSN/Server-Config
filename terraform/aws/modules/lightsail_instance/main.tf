locals {
  name          = "${var.project}_${var.purpose}"
  user_data_url = coalesce(var.user_data_url, "https://akashisn.info/${var.purpose}_lightsail.sh")
  user_data     = coalesce(var.user_data, "curl -fsSL ${local.user_data_url} | bash")
}

resource "aws_lightsail_instance" "this" {
  name              = local.name
  availability_zone = var.availability_zone
  blueprint_id      = var.blueprint_id
  bundle_id         = var.bundle_id
  ip_address_type   = var.ip_address_type
  key_pair_name     = aws_lightsail_key_pair.this.name
  user_data         = local.user_data

  tags = {
    Name = local.name
  }
}

resource "aws_lightsail_disk" "this" {
  for_each = var.disks

  name              = "${local.name}-${each.key}"
  size_in_gb        = each.value.size_in_gb
  availability_zone = var.availability_zone
}

resource "aws_lightsail_disk_attachment" "this" {
  for_each = var.disks

  disk_name     = aws_lightsail_disk.this[each.key].name
  instance_name = aws_lightsail_instance.this.name
  disk_path     = each.value.disk_path
}

resource "aws_lightsail_static_ip" "this" {
  name = "${local.name}-ip"
}

resource "aws_lightsail_static_ip_attachment" "this" {
  static_ip_name = aws_lightsail_static_ip.this.id
  instance_name  = aws_lightsail_instance.this.name

  lifecycle {
    replace_triggered_by = [
      aws_lightsail_instance.this
    ]
  }
}

resource "aws_lightsail_instance_public_ports" "this" {
  instance_name = aws_lightsail_instance.this.name

  dynamic "port_info" {
    for_each = var.ports
    content {
      protocol   = port_info.value.protocol
      from_port  = port_info.value.from_port
      to_port    = port_info.value.to_port
      cidrs      = port_info.value.cidrs
      ipv6_cidrs = port_info.value.ipv6_cidrs
    }
  }

  lifecycle {
    replace_triggered_by = [
      aws_lightsail_instance.this
    ]
  }
}
