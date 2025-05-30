
resource "aws_security_group" "efs" {
  name        = "${var.project}_sg-efs"
  description = "${var.project}_sg-efs"
  vpc_id      = var.vpc.id

  ingress {
    description = "allow-nfs-from-vpc"
    from_port   = 2049
    to_port     = 2049
    protocol    = "tcp"
    cidr_blocks = [
      var.vpc.cidr
    ]
  }

  tags = {
    Name = "${var.project}_sg-efs"
  }
}
