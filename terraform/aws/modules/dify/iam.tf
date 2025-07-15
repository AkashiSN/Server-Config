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

# ECS Exec policy
data "aws_iam_policy_document" "ecs_ssm_policy" {
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

resource "aws_iam_policy" "ecs_ssm_policy" {
  name        = "${var.project}-dify-ssm-policy"
  description = "SSM access policy for Dify ECS tasks"
  policy      = data.aws_iam_policy_document.ecs_ssm_policy.json

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
    "s3:DeleteObject"]
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

# ECR Policy
data "aws_iam_policy_document" "ecr" {
  statement {
    actions = [
      "ecr:BatchGetImage",
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchImportUpstreamImage",
      "ecr:GetImageCopyStatus"
    ]
    resources = ["arn:aws:ecr:${local.region}:${local.account_id}:repository/*"]
  }
}
resource "aws_iam_policy" "ecr" {
  name   = "${var.project}-dify-ecr-policy"
  policy = data.aws_iam_policy_document.ecr.json

  tags = {
    Name = "${var.project}-dify-ecr-policy"
  }
}

# Execution Role
resource "aws_iam_role" "ecs_execution" {
  name               = "${var.project}-dify-task-execution-role"
  description        = "AmazonECSTaskExecutionRole for Dify"
  assume_role_policy = data.aws_iam_policy_document.ecs_task.json
}

resource "aws_iam_role_policy_attachment" "ecs_execution_role_policy" {
  role       = aws_iam_role.ecs_execution.id
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy_attachment" "ecs_execution_role_get_secret_policy" {
  role       = aws_iam_role.ecs_execution.id
  policy_arn = aws_iam_policy.get_secret.arn
}

resource "aws_iam_role_policy_attachment" "ecs_execution_role_ssm_policy" {
  role       = aws_iam_role.ecs_execution.id
  policy_arn = aws_iam_policy.ecs_ssm_policy.arn
}

resource "aws_iam_role_policy_attachment" "ecs_execution_role_ecr_policy" {
  role       = aws_iam_role.ecs_execution.id
  policy_arn = aws_iam_policy.ecr.arn
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

resource "aws_iam_role_policy_attachment" "ecs_app_ssm" {
  role       = aws_iam_role.ecs_app.id
  policy_arn = aws_iam_policy.ecs_ssm_policy.arn
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

resource "aws_iam_role_policy_attachment" "ecs_web_cloudwatch_logs" {
  role       = aws_iam_role.ecs_web.name
  policy_arn = aws_iam_policy.ecs_cloudwatch_logs.arn
}

resource "aws_iam_role_policy_attachment" "ecs_web_ssm" {
  role       = aws_iam_role.ecs_web.id
  policy_arn = aws_iam_policy.ecs_ssm_policy.arn
}
