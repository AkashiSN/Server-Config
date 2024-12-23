resource "aws_vpc" "main" {
  cidr_block           = "10.226.0.0/16"
  enable_dns_hostnames = true

  tags = {
    Name = "${var.project}_vpc"
  }
}

resource "aws_subnet" "private_a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.226.10.0/24"
  availability_zone = "ap-northeast-1a"

  tags = {
    Name = "${var.project}_private-a"
  }
}

resource "aws_subnet" "private_c" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.226.20.0/24"
  availability_zone = "ap-northeast-1c"

  tags = {
    Name = "${var.project}_private-c"
  }
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project}_private"
  }
}

resource "aws_route_table_association" "private_a" {
  subnet_id      = aws_subnet.private_a.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "private_c" {
  subnet_id      = aws_subnet.private_c.id
  route_table_id = aws_route_table.private.id
}
