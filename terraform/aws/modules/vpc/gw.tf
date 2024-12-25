resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
}

resource "aws_eip" "ngw_a" {
  domain = "vpc"

  tags = {
    Name = "${var.project}_ngw-a"
  }

  depends_on = [aws_internet_gateway.igw]
}

resource "aws_eip" "ngw_c" {
  domain = "vpc"

  tags = {
    Name = "${var.project}_ngw-c"
  }

  depends_on = [aws_internet_gateway.igw]
}

resource "aws_nat_gateway" "ngw_a" {
  allocation_id = aws_eip.ngw_a.id
  subnet_id     = aws_subnet.public_a.id

  tags = {
    Name = "${var.project}_ngw-a"
  }

  depends_on = [aws_internet_gateway.igw]
}

resource "aws_nat_gateway" "ngw_c" {
  allocation_id = aws_eip.ngw_c.id
  subnet_id     = aws_subnet.public_c.id

  tags = {
    Name = "${var.project}_ngw-c"
  }

  depends_on = [aws_internet_gateway.igw]
}
