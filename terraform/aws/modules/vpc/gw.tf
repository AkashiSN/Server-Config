resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
}

resource "aws_eip" "ngw" {
  count  = 2
  domain = "vpc"

  tags = {
    Name = "${var.project}_eip-ngw-${local.az_suffix[count.index]}"
  }

  depends_on = [aws_internet_gateway.igw]
}

resource "aws_nat_gateway" "ngw" {
  count         = 2
  allocation_id = aws_eip.ngw[count.index].id
  subnet_id     = aws_subnet.main[count.index + 2].id

  tags = {
    Name = "${var.project}_ngw-${local.az_suffix[count.index]}"
  }

  depends_on = [aws_internet_gateway.igw]
}
