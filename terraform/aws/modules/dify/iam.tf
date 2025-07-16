# Assume role policy
data "aws_iam_policy_document" "ecs_task" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

# ECS Exec policy
data "aws_iam_policy_document" "ecs_ssm" {
  statement {
    actions = [
      "ssmmessages:CreateControlChannel",
      "ssmmessages:CreateDataChannel",
      "ssmmessages:OpenControlChannel",
      "ssmmessages:OpenDataChannel"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "ecs_ssm" {
  name        = "${var.project}-dify-ssm-policy"
  description = "SSM access policy for Dify ECS tasks"
  policy      = data.aws_iam_policy_document.ecs_ssm.json

  tags = {
    Name = "${var.project}-dify-ssm-policy"
  }
}

# SSM Parameter store
data "aws_iam_policy_document" "get_secret" {
  statement {
    actions = [
      "ssm:GetParameter",
      "ssm:GetParameters"
    ]
    resources = ["arn:aws:ssm:*:${local.account_id}:parameter/*"]
  }
  statement {
    actions   = ["secretsmanager:GetSecretValue"]
    resources = ["${aws_rds_cluster.dify.master_user_secret[0].secret_arn}"]
  }
}

resource "aws_iam_policy" "get_secret" {
  name   = "${var.project}-dify-get-secret-policy"
  policy = data.aws_iam_policy_document.get_secret.json

  tags = {
    Name = "${var.project}-dify-get-secret-policy"
  }
}

# Cloudwatch logs policy
data "aws_iam_policy_document" "ecs_cloudwatch_logs" {
  statement {
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:DescribeLogStreams",
      "logs:DescribeLogGroups",
      "logs:PutLogEvents",
      "xray:PutTelemetryRecords",
      "xray:PutTraceSegments",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "ecs_cloudwatch_logs" {
  name        = "${var.project}-dify-cloudwatch-policy"
  description = "Cloudwatch access policy for Dify ECS tasks"
  policy      = data.aws_iam_policy_document.ecs_cloudwatch_logs.json

  tags = {
    Name = "${var.project}-dify-cloudwatch-policy"
  }
}

# S3 policy
data "aws_iam_policy_document" "ecs_s3" {
  statement {
    actions = ["s3:ListBucket"]
    resources = [
      aws_s3_bucket.storage.arn,
      aws_s3_bucket.plugin_storage.arn,
    ]
  }
  statement {
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject"
    ]
    resources = [
      "${aws_s3_bucket.storage.arn}/*",
      "${aws_s3_bucket.plugin_storage.arn}/*"
    ]
  }
}

resource "aws_iam_policy" "ecs_s3" {
  name        = "${var.project}-dify-s3-policy"
  description = "S3 access policy for Dify ECS tasks"
  policy      = data.aws_iam_policy_document.ecs_s3.json

  tags = {
    Name = "${var.project}-dify-s3-policy"
  }
}

# Bedrock policy
data "aws_iam_policy_document" "ecs_bedrock" {
  statement {
    actions   = ["bedrock:InvokeModel"]
    resources = ["arn:aws:bedrock:*::foundation-model/*"]
  }
}

resource "aws_iam_policy" "ecs_bedrock" {
  name   = "${var.project}-dify-bedrock-policy"
  policy = data.aws_iam_policy_document.ecs_bedrock.json

  tags = {
    Name = "${var.project}-dify-bedrock-policy"
  }
}

# Elasticache policy
data "aws_iam_policy_document" "ecs_elasticache" {
  statement {
    actions = ["elasticache:Connect"]
    resources = [
      aws_elasticache_replication_group.dify.arn,
      aws_elasticache_user.dify.arn
    ]
  }
}

resource "aws_iam_policy" "ecs_elasticache" {
  name   = "${var.project}-dify-elasticache-policy"
  policy = data.aws_iam_policy_document.ecs_elasticache.json

  tags = {
    Name = "${var.project}-dify-elasticache-policy"
  }
}

# Execution Role
resource "aws_iam_role" "ecs_execution" {
  name               = "${var.project}-dify-task-execution-role"
  description        = "AmazonECSTaskExecutionRole for Dify"
  assume_role_policy = data.aws_iam_policy_document.ecs_task.json
}

resource "aws_iam_role_policy_attachment" "ecs_execution_policy" {
  role       = aws_iam_role.ecs_execution.id
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy_attachment" "ecs_execution_ecr_policy" {
  role       = aws_iam_role.ecs_execution.id
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_role_policy_attachment" "ecs_execution_role_ssm_policy" {
  role       = aws_iam_role.ecs_execution.id
  policy_arn = aws_iam_policy.ecs_ssm.arn
}

resource "aws_iam_role_policy_attachment" "ecs_execution_get_secret_policy" {
  role       = aws_iam_role.ecs_execution.id
  policy_arn = aws_iam_policy.get_secret.arn
}

# App task role
resource "aws_iam_role" "ecs_app" {
  name               = "${var.project}-dify-app"
  description        = "Task Role for Dify API, Worker and Sandbox"
  assume_role_policy = data.aws_iam_policy_document.ecs_task.json

  tags = {
    Name = "${var.project}-dify-app"
  }
}

resource "aws_iam_role_policy_attachment" "ecs_app_ssm" {
  role       = aws_iam_role.ecs_app.id
  policy_arn = aws_iam_policy.ecs_ssm.arn
}

resource "aws_iam_role_policy_attachment" "ecs_app_cloudwatch_logs" {
  role       = aws_iam_role.ecs_app.name
  policy_arn = aws_iam_policy.ecs_cloudwatch_logs.arn
}

resource "aws_iam_role_policy_attachment" "ecs_app_s3" {
  role       = aws_iam_role.ecs_app.name
  policy_arn = aws_iam_policy.ecs_s3.arn
}

resource "aws_iam_role_policy_attachment" "ecs_app_bedrock" {
  role       = aws_iam_role.ecs_app.id
  policy_arn = aws_iam_policy.ecs_bedrock.arn
}

resource "aws_iam_role_policy_attachment" "ecs_app_elasticache" {
  role       = aws_iam_role.ecs_app.id
  policy_arn = aws_iam_policy.ecs_elasticache.arn
}


# Web task role
resource "aws_iam_role" "ecs_web" {
  name               = "${var.project}-dify-web"
  description        = "Task Role for Dify Web"
  assume_role_policy = data.aws_iam_policy_document.ecs_task.json

  tags = {
    Name = "${var.project}-dify-web"
  }
}

resource "aws_iam_role_policy_attachment" "ecs_web_ssm" {
  role       = aws_iam_role.ecs_web.id
  policy_arn = aws_iam_policy.ecs_ssm.arn
}

resource "aws_iam_role_policy_attachment" "ecs_web_cloudwatch_logs" {
  role       = aws_iam_role.ecs_web.name
  policy_arn = aws_iam_policy.ecs_cloudwatch_logs.arn
}
