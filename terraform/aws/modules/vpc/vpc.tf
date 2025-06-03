resource "aws_vpc" "main" {
  cidr_block                       = var.cidr_block
  enable_dns_support               = true
  enable_dns_hostnames             = true
  assign_generated_ipv6_cidr_block = true

  tags = {
    Name = "${var.project}_vpc"
  }
}

resource "aws_subnet" "main" {
  count = 4

  vpc_id            = aws_vpc.main.id
  availability_zone = local.subnet.availability_zones[count.index]

  cidr_block      = cidrsubnet(var.cidr_block, 8, (count.index + 1) * 10)
  ipv6_cidr_block = cidrsubnet(aws_vpc.main.ipv6_cidr_block, 8, (count.index + 1) * 10)

  tags = merge(
    { Name = "${var.project}_${local.subnet.name_suffix[count.index]}" },
    local.subnet.tags[count.index]
  )
}

resource "aws_route_table" "private" {
  count = 2

  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.ngw[count.index].id
  }

  tags = {
    Name = "${var.project}_${local.subnet.name_suffix[count.index]}"
  }
}

resource "aws_route_table_association" "private" {
  count = 2

  subnet_id      = aws_subnet.main[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

resource "aws_route_table" "public" {
  count = 2

  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "${var.project}_${local.subnet.name_suffix[count.index + 2]}"
  }
}

resource "aws_route_table_association" "public" {
  count = 2

  subnet_id      = aws_subnet.main[count.index + 2].id
  route_table_id = aws_route_table.public[count.index].id
}
