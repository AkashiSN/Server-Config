# Log Group
resource "aws_cloudwatch_log_group" "dify" {
  name              = "/ecs/dify/container-logs"
  retention_in_days = 30 # TODO: variable
}
