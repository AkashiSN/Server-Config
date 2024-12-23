data "aws_iam_policy_document" "vpc_endpoint" {
  statement {
    effect    = "Allow"
    actions   = ["*"]
    resources = ["*"]
    principals {
      type        = "AWS"
      identifiers = ["*"]
    }
  }
}

resource "aws_vpc_endpoint" "ssm" {
  vpc_endpoint_type = "Interface"
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.ap-northeast-1.ssm"
  policy            = data.aws_iam_policy_document.vpc_endpoint.json
  subnet_ids = [
    aws_subnet.private_a.id,
    aws_subnet.private_c.id
  ]
  private_dns_enabled = true
  security_group_ids = [
    aws_security_group.ssm.id
  ]

  tags = {
    Name = "${var.project}_vpce-ssm"
  }
}

resource "aws_vpc_endpoint" "ssmmessages" {
  vpc_endpoint_type = "Interface"
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.ap-northeast-1.ssmmessages"
  policy            = data.aws_iam_policy_document.vpc_endpoint.json
  subnet_ids = [
    aws_subnet.private_a.id,
    aws_subnet.private_c.id
  ]
  private_dns_enabled = true
  security_group_ids = [
    aws_security_group.ssm.id
  ]
  tags = {
    Name = "${var.project}_vpce-ssmmessages"
  }
}

resource "aws_vpc_endpoint" "ec2messages" {
  vpc_endpoint_type = "Interface"
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.ap-northeast-1.ec2messages"
  policy            = data.aws_iam_policy_document.vpc_endpoint.json
  subnet_ids = [
    aws_subnet.private_a.id,
    aws_subnet.private_c.id
  ]
  private_dns_enabled = true
  security_group_ids = [
    aws_security_group.ssm.id
  ]
  tags = {
    Name = "${var.project}_vpce-ec2messages"
  }
}

resource "aws_vpc_endpoint" "s3" {
  vpc_endpoint_type = "Gateway"
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.ap-northeast-1.s3"
  policy            = data.aws_iam_policy_document.vpc_endpoint.json
  tags = {
    Name = "${var.project}_vpce-s3"
  }
}

resource "aws_vpc_endpoint_route_table_association" "private" {
  route_table_id  = aws_route_table.private.id
  vpc_endpoint_id = aws_vpc_endpoint.s3.id
}
