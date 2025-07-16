resource "aws_ecr_repository" "dify_api" {
  name                 = "docker.io/langgenius/dify-api"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecr_repository" "dify_web" {
  name                 = "docker.io/langgenius/dify-web"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecr_repository" "dify_sandbox" {
  name                 = "docker.io/langgenius/dify-sandbox"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecr_repository" "dify_plugin_daemon" {
  name                 = "docker.io/langgenius/dify-plugin-daemon"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "terraform_data" "pull_and_push_image" {
  triggers_replace = [
    md5(file("${path.module}/scripts/push_image.sh"))
  ]
  provisioner "local-exec" {
    command = "sh ${path.module}/scripts/push_image.sh"

    environment = {
      AWS_REGION     = local.region
      AWS_ACCOUNT_ID = local.account_id

      DIFY_API_VERSION           = var.dify_version.api
      DIFY_WEB_VERSION           = var.dify_version.web
      DIFY_SANDBOX_VERSION       = var.dify_version.sandbox
      DIFY_PLUGIN_DAEMON_VERSION = var.dify_version.plugin_daemon

      DIFY_API_REPO_URL           = aws_ecr_repository.dify_api.repository_url
      DIFY_WEB_REPO_URL           = aws_ecr_repository.dify_web.repository_url
      DIFY_SANDBOX_REPO_URL       = aws_ecr_repository.dify_sandbox.repository_url
      DIFY_PLUGIN_DAEMON_REPO_URL = aws_ecr_repository.dify_plugin_daemon.repository_url
    }
  }
}

locals {
  dify_repo_url = {
    api           = aws_ecr_repository.dify_api.repository_url
    web           = aws_ecr_repository.dify_web.repository_url
    sandbox       = aws_ecr_repository.dify_sandbox.repository_url
    plugin_daemon = aws_ecr_repository.dify_plugin_daemon.repository_url
  }
}
