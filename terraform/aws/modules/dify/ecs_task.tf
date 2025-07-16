resource "aws_ecs_task_definition" "dify_api" {
  family                   = "${var.project}-dify-api"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.dify_resource.api.cpu
  memory                   = var.dify_resource.api.memory
  execution_role_arn       = aws_iam_role.ecs_execution.arn
  task_role_arn            = aws_iam_role.ecs_app.arn

  container_definitions = jsonencode([
    {
      name       = "dify-api"
      image      = "${local.dify_repo_url.api}:${var.dify_version.api}"
      essential  = true
      entryPoint = ["/bin/sh"]
      command    = ["-c", local.app_command]
      portMappings = [{
        hostPort      = 5001
        protocol      = "tcp"
        containerPort = 5001
      }]
      environment = [for name, value in local.dify_api_env : { name = name, value = tostring(value) }]
      secrets = [
        {
          name      = "SECRET_KEY"
          valueFrom = data.aws_ssm_parameter.session_secret_key.name
        },
        {
          name      = "REDIS_PASSWORD"
          valueFrom = data.aws_ssm_parameter.elasticache_dify_password.name
        },
        {
          name      = "CELERY_BROKER_URL"
          valueFrom = aws_ssm_parameter.celery_broker_url.name
        },
        {
          name      = "DB_PASSWORD"
          valueFrom = "${aws_rds_cluster.dify.master_user_secret[0].secret_arn}:password::"
        },
        {
          name      = "INNER_API_KEY_FOR_PLUGIN"
          valueFrom = data.aws_ssm_parameter.dify_inner_api_key.name
        },
        {
          name      = "PLUGIN_DAEMON_KEY"
          valueFrom = data.aws_ssm_parameter.plugin_daemon_key.name
        },
        {
          name      = "CODE_EXECUTION_API_KEY"
          valueFrom = data.aws_ssm_parameter.sandbox_key.name
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.dify.name
          "awslogs-region"        = local.region
          "awslogs-stream-prefix" = "dify-api"
        }
      }
      healthCheck = {
        command     = ["CMD-SHELL", "curl -f http://localhost:5001/health || exit 1"]
        interval    = 10
        timeout     = 5
        retries     = 3
        startPeriod = 60
      }
      cpu         = 0
      volumesFrom = []
      mountPoints = []
    },
    {
      name      = "dify-plugin-daemon"
      image     = "${local.dify_repo_url.plugin_daemon}:${var.dify_version.plugin_daemon}"
      essential = true
      dependsOn = [{
        containerName = "dify-api"
        condition     = "START"
      }]
      portMappings = [
        {
          hostPort      = 5002
          protocol      = "tcp"
          containerPort = 5002
        },
        {
          hostPort      = 5003
          protocol      = "tcp"
          containerPort = 5003
        }
      ]
      environment = [for name, value in local.dify_plugin_daemon_env : { name = name, value = tostring(value) }]
      secrets = [
        {
          name      = "SERVER_KEY"
          valueFrom = data.aws_ssm_parameter.plugin_daemon_key.name
        },
        {
          name      = "REDIS_PASSWORD"
          valueFrom = data.aws_ssm_parameter.elasticache_dify_password.name
        },
        {
          name      = "DB_PASSWORD"
          valueFrom = "${aws_rds_cluster.dify.master_user_secret[0].secret_arn}:password::"
        },
        {
          name      = "DIFY_INNER_API_KEY"
          valueFrom = data.aws_ssm_parameter.dify_inner_api_key.name
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.dify.name
          "awslogs-region"        = local.region
          "awslogs-stream-prefix" = "dify-plugin-daemon"
        }
      }
      healthCheck = {
        command     = ["CMD-SHELL", "curl -f http://localhost:5002/health/check || exit 1"]
        interval    = 10
        timeout     = 5
        retries     = 3
        startPeriod = 60
      }
      cpu         = 0
      volumesFrom = []
      mountPoints = []
    },
    {
      name      = "dify-sandbox"
      image     = "${local.dify_repo_url.sandbox}:${var.dify_version.sandbox}"
      essential = true
      portMappings = [{
        hostPort      = 8194
        protocol      = "tcp"
        containerPort = 8194
      }]
      environment = [for name, value in local.dify_sandbox_env : { name = name, value = tostring(value) }]
      secrets = [{
        name      = "API_KEY"
        valueFrom = data.aws_ssm_parameter.sandbox_key.name
      }]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.dify.name
          "awslogs-region"        = local.region
          "awslogs-stream-prefix" = "dify-sandbox"
        }
      }
      healthCheck = {
        command     = ["CMD-SHELL", "curl -f http://localhost:8194/health || exit 1"]
        interval    = 10
        timeout     = 5
        retries     = 3
        startPeriod = 60
      }
      cpu         = 0
      volumesFrom = []
      mountPoints = []
    },
  ])

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "ARM64"
  }

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [
    aws_rds_cluster_instance.dify,
    terraform_data.pull_and_push_image
  ]
}

# Dify Worker Task
resource "aws_ecs_task_definition" "dify_worker" {
  family                   = "${var.project}-dify-worker"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.dify_resource.worker.cpu
  memory                   = var.dify_resource.worker.memory
  execution_role_arn       = aws_iam_role.ecs_execution.arn
  task_role_arn            = aws_iam_role.ecs_app.arn

  container_definitions = jsonencode([
    {
      name        = "dify-worker"
      image       = "${local.dify_repo_url.api}:${var.dify_version.api}"
      essential   = true
      environment = [for name, value in local.dify_worker_env : { name = name, value = tostring(value) }]
      secrets = [
        {
          name      = "SECRET_KEY"
          valueFrom = data.aws_ssm_parameter.session_secret_key.name
        },
        {
          name      = "REDIS_PASSWORD"
          valueFrom = data.aws_ssm_parameter.elasticache_dify_password.name
        },
        {
          name      = "CELERY_BROKER_URL"
          valueFrom = aws_ssm_parameter.celery_broker_url.name
        },
        {
          name      = "DB_PASSWORD"
          valueFrom = "${aws_rds_cluster.dify.master_user_secret[0].secret_arn}:password::"
        },
        {
          name      = "CODE_EXECUTION_API_KEY"
          valueFrom = data.aws_ssm_parameter.sandbox_key.name
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.dify.name
          "awslogs-region"        = local.region
          "awslogs-stream-prefix" = "dify-worker"
        }
      }
      cpu         = 0
      volumesFrom = []
      mountPoints = []
    },
  ])

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "ARM64"
  }

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [
    aws_rds_cluster_instance.dify,
    terraform_data.pull_and_push_image
  ]
}

resource "aws_ecs_task_definition" "dify_web" {
  family                   = "${var.project}-dify-web"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.dify_resource.web.cpu
  memory                   = var.dify_resource.web.memory
  execution_role_arn       = aws_iam_role.ecs_execution.arn
  task_role_arn            = aws_iam_role.ecs_web.arn

  container_definitions = jsonencode([
    {
      name        = "dify-web"
      image       = "${local.dify_repo_url.web}:${var.dify_version.web}"
      essential   = true
      environment = [for name, value in local.dify_web_env : { name = name, value = tostring(value) }]
      portMappings = [{
        hostPort      = 3000
        protocol      = "tcp"
        containerPort = 3000
      }]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.dify.name
          "awslogs-region"        = local.region
          "awslogs-stream-prefix" = "dify-web"
        }
      }
      cpu         = 0
      volumesFrom = []
      mountPoints = []
    },
  ])

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "ARM64"
  }

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [terraform_data.pull_and_push_image]
}
