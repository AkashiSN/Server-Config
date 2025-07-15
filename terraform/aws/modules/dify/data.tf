data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

data "aws_vpc" "this" {
  id = var.vpc.id
}

# A secret key that is used for securely signing the session cookie
# and encrypting sensitive information on the database.
# You can generate a strong key using `openssl rand -base64 42`.
data "aws_ssm_parameter" "session_secret_key" {
  name = "/${var.project}/dify/SESSION_SECRET_KEY"
}

# DifySandbox api key
data "aws_ssm_parameter" "sandbox_key" {
  name = "/${var.project}/dify/SANDBOX_API_KEY"
}

# Plugin daemon server key
data "aws_ssm_parameter" "plugin_daemon_key" {
  name = "/${var.project}/dify/PLUGIN_DAEMON_KEY"
}

# API Key for plugin daemon
data "aws_ssm_parameter" "dify_inner_api_key" {
  name = "/${var.project}/dify/DIFY_INNER_API_KEY"
}


locals {
  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.name
}
