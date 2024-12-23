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
    description = "allow-https-from-vpc"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [
      aws_vpc.main.cidr_block
    ]
  }

  tags = {
    Name = "${var.project}_sg-ssm"
  }
}

resource "aws_security_group" "eks_cluster" {
  name        = "${var.project}_sg-eks-cluster"
  description = "${var.project}_sg-eks-cluster"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "allow-all-from-self-sg"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true
  }

  egress {
    description = "allow-all-outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project}_sg-eks-cluster"
  }
}

resource "aws_security_group" "eks_workernode" {
  name        = "${var.project}_sg-eks-workernode"
  description = "${var.project}_sg-eks-workernode"
  vpc_id      = aws_vpc.main.id

  egress {
    description = "allow-all-outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project}_sg-eks-workernode"
  }
}
