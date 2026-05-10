resource "aws_security_group" "this" {
  name        = "${var.project}-efs"
  description = "Allow NFS from Lightsail CIDR"
  vpc_id      = data.aws_vpc.default.id

  tags = {
    Name = "${var.project}-efs"
  }
}

resource "aws_vpc_security_group_ingress_rule" "nfs" {
  security_group_id = aws_security_group.this.id
  cidr_ipv4         = var.lightsail_cidr
  ip_protocol       = "tcp"
  from_port         = 2049
  to_port           = 2049
  description       = "NFS from Lightsail"
}
