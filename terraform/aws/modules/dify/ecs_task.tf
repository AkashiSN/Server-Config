locals {
  dify_base_env = {
    # The log level for the application. Supported values are `DEBUG`, `INFO`, `WARNING`, `ERROR`, `CRITICAL`
    LOG_LEVEL = "INFO"
    # enable DEBUG mode to output more logs
    # DEBUG  = "true"
    # The configurations of postgres database connection.
    # It is consistent with the configuration in the 'db' service below.
    DB_USERNAME = "dify"
    DB_HOST     = aws_rds_cluster.dify.endpoint
    DB_PORT     = aws_rds_cluster.dify.port
    DB_DATABASE = "dify"
    # The configurations of redis connection.
    # It is consistent with the configuration in the 'redis' service below.
    REDIS_HOST    = aws_elasticache_serverless_cache.dify.endpoint[0].address
    REDIS_PORT    = aws_elasticache_serverless_cache.dify.endpoint[0].port
    REDIS_USE_SSL = true
    # use redis db 0 for redis cache
    REDIS_DB = 0
    # The configurations of celery broker.
    # Use redis as the broker, and redis db 1 for celery broker.
    CELERY_BROKER_URL = "rediss://:@${aws_elasticache_serverless_cache.dify.endpoint[0].address}:${aws_elasticache_serverless_cache.dify.endpoint[0].port}/1"
    BROKER_USE_SSL    = true
    # The type of storage to use for storing user files. Supported values are `local` and `s3` and `azure-blob` and `google-storage`, Default = `local`
    STORAGE_TYPE = "s3"
    # The S3 storage configurations, only available when STORAGE_TYPE is `s3`.
    S3_USE_AWS_MANAGED_IAM = true
    S3_BUCKET_NAME         = aws_s3_bucket.storage.bucket
    S3_REGION              = local.region
    # The type of vector store to use.
    VECTOR_STORE = "opensearch"
    # open search configuration, only available when VECTOR_STORE is `opensearch`
    OPENSEARCH_HOST         = aws_opensearchserverless_collection.dify.collection_endpoint
    OPENSEARCH_PORT         = 9200
    OPENSEARCH_SECURE       = true
    OPENSEARCH_VERIFY_CERTS = true
    OPENSEARCH_AUTH_METHOD  = "basic"
    # If using AWS managed IAM, e.g. Managed Cluster or OpenSearch Serverless
    OPENSEARCH_AWS_REGION  = local.region
    OPENSEARCH_AWS_SERVICE = "aoss"
    # Indexing configuration
    INDEXING_MAX_SEGMENTATION_TOKENS_LENGTH = 1000
  }
  dify_api_env = merge(
    {
      # Startup mode, 'api' starts the API server.
      MODE = "api",
      # The base URL of console application web frontend, refers to the Console base URL of WEB service if console domain is
      # different from api or web app domain.
      CONSOLE_WEB_URL = "http://${aws_lb.dify.dns_name}"
      # The base URL of console application api server, refers to the Console base URL of WEB service if console domain is different from api or web app domain.
      CONSOLE_API_URL = "http://${aws_lb.dify.dns_name}"
      # The URL prefix for Service API endpoints, refers to the base URL of the current API service if api domain is different from console domain.
      SERVICE_API_URL = "http://${aws_lb.dify.dns_name}"
      # The URL prefix for Web APP frontend, refers to the Web App base URL of WEB service if web app domain is different from console or api domain.
      APP_WEB_URL = "http://${aws_lb.dify.dns_name}"
      # When enabled, migrations will be executed prior to application startup and the application will start after the migrations have completed.
      MIGRATION_ENABLED = "true"
      # Specifies the allowed origins for cross-origin requests to the Web API, e.g. https://dify.app or * for all origins.
      WEB_API_CORS_ALLOW_ORIGINS = "*"
      # Specifies the allowed origins for cross-origin requests to the console API, e.g. https://cloud.dify.ai or * for all origins.
      CONSOLE_CORS_ALLOW_ORIGINS = "*"
      # The sandbox service endpoint.
      CODE_EXECUTION_ENDPOINT       = "http://localhost:8194" # Fargate の task 内通信は localhost 宛
      CODE_MAX_NUMBER               = "9223372036854775807"
      CODE_MIN_NUMBER               = "-9223372036854775808"
      CODE_MAX_STRING_LENGTH        = 80000
      TEMPLATE_TRANSFORM_MAX_LENGTH = 80000
      CODE_MAX_STRING_ARRAY_LENGTH  = 30
      CODE_MAX_OBJECT_ARRAY_LENGTH  = 30
      CODE_MAX_NUMBER_ARRAY_LENGTH  = 1000
    },
    local.dify_base_env
  )
  dify_worker_env = merge(
    {
      # Startup mode, 'worker' starts the Celery worker for processing the queue.
      MODE = "worker"
    },
    local.dify_base_env
  )
}

resource "aws_ecs_task_definition" "dify_api" {
  family                   = "${var.project}-dify-api"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.dify_resource.api.cpu
  memory                   = var.dify_resource.api.memory
  execution_role_arn       = aws_iam_role.ecs_execution.arn
  task_role_arn            = aws_iam_role.ecs_app.arn

  volume {
    name = "dependencies"
  }

  container_definitions = jsonencode([
    {
      name      = "dify-api"
      image     = "langgenius/dify-api:${var.dify_version.api}"
      essential = true
      portMappings = [
        {
          hostPort      = 5001
          protocol      = "tcp"
          containerPort = 5001
        }
      ]
      environment = [
        for name, value in local.dify_api_env : { name = name, value = tostring(value) }
      ]
      secrets = [
        {
          name      = "SECRET_KEY"
          valueFrom = data.aws_ssm_parameter.session_secret_key.name
        },
        {
          name      = "DB_PASSWORD"
          valueFrom = data.aws_ssm_parameter.db_password.name
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
        startPeriod = 30
      }
      cpu         = 0
      volumesFrom = []
      mountPoints = []
    },
    {
      name      = "dify-sandbox"
      image     = "langgenius/dify-sandbox:${var.dify_version.sandbox}"
      essential = true
      mountPoints = [
        {
          sourceVolume  = "dependencies"
          containerPath = "/dependencies"
        }
      ]
      portMappings = [
        {
          hostPort      = 8194
          protocol      = "tcp"
          containerPort = 8194
        }
      ]
      environment = [
        for name, value in {
          GIN_MODE       = "release"
          WORKER_TIMEOUT = 15
          ENABLE_NETWORK = true
          SANDBOX_PORT   = 8194
        } : { name = name, value = tostring(value) }
      ]
      secrets = [
        {
          name      = "API_KEY"
          valueFrom = data.aws_ssm_parameter.sandbox_key.name
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.dify.name
          "awslogs-region"        = local.region
          "awslogs-stream-prefix" = "dify-sandbox"
        }
      }
      cpu         = 0
      volumesFrom = []
    }
  ])
  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "ARM64"
  }

  lifecycle {
    create_before_destroy = true
  }
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
      name      = "dify-worker"
      image     = "langgenius/dify-api:${var.dify_version.api}"
      essential = true
      environment = [
        for name, value in local.dify_worker_env : { name = name, value = tostring(value) }
      ]
      secrets = [
        {
          name      = "SECRET_KEY"
          valueFrom = data.aws_ssm_parameter.session_secret_key.name
        },
        {
          name      = "DB_PASSWORD"
          valueFrom = data.aws_ssm_parameter.db_password.name
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
      name      = "dify-web"
      image     = "langgenius/dify-web:${var.dify_version.web}"
      essential = true
      environment = [
        for name, value in {
          # The base URL of console application api server, refers to the Console base URL of WEB service if console domain is
          # different from api or web app domain.
          CONSOLE_API_URL = "http://${aws_lb.dify.dns_name}"
          # The URL for Web APP api server, refers to the Web App base URL of WEB service if web app domain is different from
          # console or api domain.
          APP_API_URL             = "http://${aws_lb.dify.dns_name}"
          NEXT_TELEMETRY_DISABLED = "0"
        } : { name = name, value = tostring(value) }
      ]
      portMappings = [
        {
          hostPort      = 3000
          protocol      = "tcp"
          containerPort = 3000
        }
      ]
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
}
