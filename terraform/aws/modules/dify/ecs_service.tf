# ECS Service
resource "aws_ecs_service" "api" {
  name                   = "${var.project}-dify-api"
  cluster                = aws_ecs_cluster.dify.name
  desired_count          = var.dify_resource.api.desired_count
  task_definition        = aws_ecs_task_definition.dify_api.arn
  propagate_tags         = "SERVICE"
  launch_type            = "FARGATE"
  platform_version       = "1.4.0"
  enable_execute_command = true

  network_configuration {
    subnets         = var.vpc.private_subnet_ids
    security_groups = [aws_security_group.api.id]
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.api.arn
    container_name   = "dify-api"
    container_port   = 5001
  }

  depends_on = [aws_lb_listener_rule.api]
}

resource "aws_ecs_service" "worker" {
  name                   = "${var.project}-dify-worker"
  cluster                = aws_ecs_cluster.dify.name
  desired_count          = var.dify_resource.worker.desired_count
  task_definition        = aws_ecs_task_definition.dify_worker.arn
  propagate_tags         = "SERVICE"
  launch_type            = "FARGATE"
  platform_version       = "1.4.0"
  enable_execute_command = true

  network_configuration {
    subnets         = var.vpc.private_subnet_ids
    security_groups = [aws_security_group.worker.id]
  }
}

resource "aws_ecs_service" "web" {
  name                   = "${var.project}-dify-web"
  cluster                = aws_ecs_cluster.dify.name
  desired_count          = var.dify_resource.web.desired_count
  task_definition        = aws_ecs_task_definition.dify_web.arn
  propagate_tags         = "SERVICE"
  launch_type            = "FARGATE"
  platform_version       = "1.4.0"
  enable_execute_command = true

  network_configuration {
    subnets         = var.vpc.private_subnet_ids
    security_groups = [aws_security_group.web.id]
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.web.arn
    container_name   = "dify-web"
    container_port   = 3000
  }
}
