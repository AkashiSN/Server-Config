resource "aws_vpn_gateway" "vgw" {
  tags = {
    Name = "${var.project}_vgw"
  }
}

resource "aws_vpn_gateway_attachment" "vpn_attachment" {
  vpc_id         = aws_vpc.main.id
  vpn_gateway_id = aws_vpn_gateway.vgw.id
}

resource "aws_vpn_gateway_route_propagation" "vgw_propagate_main" {
  vpn_gateway_id = aws_vpn_gateway.vgw.id
  route_table_id = aws_vpc.main.main_route_table_id
}

resource "aws_vpn_gateway_route_propagation" "vgw_propagate_private" {
  vpn_gateway_id = aws_vpn_gateway.vgw.id
  route_table_id = aws_route_table.private.id
}

resource "aws_customer_gateway" "cgw" {
  bgp_asn    = 65000 # default
  ip_address = var.homelab.global_ip_address
  type       = "ipsec.1"

  tags = {
    Name = "${var.project}_cgw"
  }
}

resource "aws_vpn_connection" "vpnc" {
  vpn_gateway_id      = aws_vpn_gateway.vgw.id
  customer_gateway_id = aws_customer_gateway.cgw.id
  type                = "ipsec.1"

  # tunnel 1
  tunnel1_ike_versions                 = ["ikev2"]
  tunnel1_phase1_dh_group_numbers      = [14]
  tunnel1_phase1_encryption_algorithms = ["AES256"]
  tunnel1_phase1_integrity_algorithms  = ["SHA2-256"]
  tunnel1_phase2_dh_group_numbers      = [14]
  tunnel1_phase2_encryption_algorithms = ["AES256"]
  tunnel1_phase2_integrity_algorithms  = ["SHA2-256"]

  # tunnel 2
  tunnel2_ike_versions                 = ["ikev2"]
  tunnel2_phase1_dh_group_numbers      = [14]
  tunnel2_phase1_encryption_algorithms = ["AES256"]
  tunnel2_phase1_integrity_algorithms  = ["SHA2-256"]
  tunnel2_phase2_dh_group_numbers      = [14]
  tunnel2_phase2_encryption_algorithms = ["AES256"]
  tunnel2_phase2_integrity_algorithms  = ["SHA2-256"]

  tags = {
    Name = "${var.project}_vpnc"
  }
}
