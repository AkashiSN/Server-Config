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

resource "aws_ec2_instance_connect_endpoint" "eic" {
  subnet_id          = aws_subnet.main[0].id
  security_group_ids = [aws_security_group.eic_endpoint.id]

  tags = {
    Name = "${var.project}_eice"
  }
}

resource "aws_vpc_endpoint" "ssm" {
  vpc_endpoint_type = "Interface"
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.ap-northeast-1.ssm"
  policy            = data.aws_iam_policy_document.vpc_endpoint.json
  subnet_ids = [
    aws_subnet.main[0].id,
    aws_subnet.main[1].id
  ]
  private_dns_enabled = true
  security_group_ids = [
    aws_security_group.ssm_endpoint.id
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
    aws_subnet.main[0].id,
    aws_subnet.main[1].id
  ]
  private_dns_enabled = true
  security_group_ids = [
    aws_security_group.ssm_endpoint.id
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
    aws_subnet.main[0].id,
    aws_subnet.main[1].id
  ]
  private_dns_enabled = true
  security_group_ids = [
    aws_security_group.ssm_endpoint.id
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

resource "aws_vpc_endpoint_route_table_association" "s3_private" {
  count           = 2
  route_table_id  = aws_route_table.private[count.index].id
  vpc_endpoint_id = aws_vpc_endpoint.s3.id
}

resource "aws_vpc_endpoint" "logs" {
  vpc_endpoint_type   = "Interface"
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.ap-northeast-1.logs"
  policy              = data.aws_iam_policy_document.vpc_endpoint.json
  private_dns_enabled = true
  subnet_ids = [
    aws_subnet.main[0].id,
    aws_subnet.main[1].id
  ]
  security_group_ids = [
    aws_security_group.logs_endpoint.id
  ]
}

resource "aws_vpc_endpoint" "ecr_api" {
  vpc_endpoint_type = "Interface"
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.ap-northeast-1.ecr.api"
  policy            = data.aws_iam_policy_document.vpc_endpoint.json
  subnet_ids = [
    aws_subnet.main[0].id,
    aws_subnet.main[1].id
  ]
  private_dns_enabled = true
  security_group_ids = [
    aws_security_group.ecr_endpoint.id
  ]
  tags = {
    Name = "${var.project}_vpce-ecr_api"
  }
}

resource "aws_vpc_endpoint" "ecr_dkr" {
  vpc_endpoint_type = "Interface"
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.ap-northeast-1.ecr.dkr"
  policy            = data.aws_iam_policy_document.vpc_endpoint.json
  subnet_ids = [
    aws_subnet.main[0].id,
    aws_subnet.main[1].id
  ]
  private_dns_enabled = true
  security_group_ids = [
    aws_security_group.ecr_endpoint.id
  ]
  tags = {
    Name = "${var.project}_vpce-ecr_dkr"
  }
}
