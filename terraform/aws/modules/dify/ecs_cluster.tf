# ECS Cluster
resource "aws_ecs_cluster" "dify" {
  name = "${var.project}-dify"
  setting {
    name  = "containerInsights"
    value = "enhanced"
  }

  tags = {
    Name = "${var.project}-dify"
  }
}

resource "aws_ecs_cluster_capacity_providers" "dify" {
  cluster_name       = aws_ecs_cluster.dify.name
  capacity_providers = ["FARGATE", "FARGATE_SPOT"]

  default_capacity_provider_strategy {
    capacity_provider = "FARGATE"
    weight            = 1
  }
}
