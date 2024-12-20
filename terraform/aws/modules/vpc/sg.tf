resource "aws_default_security_group" "default" {
  vpc_id = aws_vpc.main.id

  ingress {
    description = "allow-icmp-inbound"
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "allow-all-outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "ssm" {
  name        = "${var.project}_sg-ssm"
  description = "${var.project}_sg-ssm"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port = 443
    to_port   = 443
    protocol  = "tcp"
    cidr_blocks = [
      aws_vpc.main.cidr_block
    ]
  }

  tags = {
    Name = "${var.project}_sg-ssm"
  }
}
