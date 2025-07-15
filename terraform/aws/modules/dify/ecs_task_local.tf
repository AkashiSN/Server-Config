locals {
  dify_base_env = {
    # The log level for the application. Supported values are `DEBUG`, `INFO`, `WARNING`, `ERROR`, `CRITICAL`
    LOG_LEVEL = "INFO"
  }
  # https://github.com/langgenius/dify/blob/main/api/.env.example
  dify_app_env = {
    # Console API base URL
    CONSOLE_API_URL = "http://${aws_lb.dify.dns_name}"
    CONSOLE_WEB_URL = "http://${aws_lb.dify.dns_name}"

    # Service API base URL
    SERVICE_API_URL = "http://${aws_lb.dify.dns_name}"

    # Web APP base URL
    APP_WEB_URL = "http://${aws_lb.dify.dns_name}"

    # The time in seconds after the signature is rejected
    FILES_ACCESS_TIMEOUT = 300

    # Access token expiration time in minutes
    ACCESS_TOKEN_EXPIRE_MINUTES = 60

    # Refresh token expiration time in days
    REFRESH_TOKEN_EXPIRE_DAYS = 30

    # redis configuration
    REDIS_HOST     = local.redis_serverless_host
    REDIS_PORT     = local.redis_serverless_port
    REDIS_USERNAME = ""
    REDIS_PASSWORD = ""
    REDIS_USE_SSL  = true
    REDIS_DB       = 0 # use redis db 0 for redis cache

    # celery configuration
    CELERY_BROKER_URL = "rediss://:@${local.redis_serverless_host}:${local.redis_serverless_port}/1"
    BROKER_USE_SSL    = true

    # PostgreSQL database configuration
    DB_USERNAME = "dify"
    DB_HOST     = aws_rds_cluster.dify.endpoint
    DB_PORT     = aws_rds_cluster.dify.port
    DB_DATABASE = "dify"

    # Storage configuration
    # use for store upload files, private keys...
    STORAGE_TYPE           = "s3"
    S3_BUCKET_NAME         = aws_s3_bucket.storage.bucket
    S3_REGION              = local.region
    S3_USE_AWS_MANAGED_IAM = true

    # CORS configuration
    WEB_API_CORS_ALLOW_ORIGINS = "*"
    CONSOLE_CORS_ALLOW_ORIGINS = "*"

    # Vector database configuration
    VECTOR_STORE            = "opensearch"
    OPENSEARCH_HOST         = aws_opensearchserverless_collection.dify.collection_endpoint
    OPENSEARCH_PORT         = 9200
    OPENSEARCH_SECURE       = true
    OPENSEARCH_VERIFY_CERTS = true
    OPENSEARCH_AUTH_METHOD  = "basic"
    OPENSEARCH_AWS_REGION   = local.region
    OPENSEARCH_AWS_SERVICE  = "aoss"

    # Upload configuration
    UPLOAD_FILE_SIZE_LIMIT       = 15
    UPLOAD_FILE_BATCH_LIMIT      = 5
    UPLOAD_IMAGE_FILE_SIZE_LIMIT = 10
    UPLOAD_VIDEO_FILE_SIZE_LIMIT = 100
    UPLOAD_AUDIO_FILE_SIZE_LIMIT = 50

    # Model configuration
    MULTIMODAL_SEND_FORMAT              = "base64"
    PROMPT_GENERATION_MAX_TOKENS        = 512
    CODE_GENERATION_MAX_TOKENS          = 1024
    PLUGIN_BASED_TOKEN_COUNTING_ENABLED = false

    # CODE EXECUTION CONFIGURATION
    CODE_EXECUTION_ENDPOINT       = "http://127.0.0.1:8194"
    CODE_MAX_NUMBER               = 9223372036854775807
    CODE_MIN_NUMBER               = -9223372036854775808
    CODE_MAX_STRING_LENGTH        = 80000
    TEMPLATE_TRANSFORM_MAX_LENGTH = 80000
    CODE_MAX_STRING_ARRAY_LENGTH  = 30
    CODE_MAX_OBJECT_ARRAY_LENGTH  = 30
    CODE_MAX_NUMBER_ARRAY_LENGTH  = 1000

    # API Tool configuration
    API_TOOL_DEFAULT_CONNECT_TIMEOUT = 10
    API_TOOL_DEFAULT_READ_TIMEOUT    = 60

    # HTTP Node configuration
    HTTP_REQUEST_MAX_CONNECT_TIMEOUT  = 300
    HTTP_REQUEST_MAX_READ_TIMEOUT     = 600
    HTTP_REQUEST_MAX_WRITE_TIMEOUT    = 600
    HTTP_REQUEST_NODE_MAX_BINARY_SIZE = 10485760
    HTTP_REQUEST_NODE_MAX_TEXT_SIZE   = 1048576
    HTTP_REQUEST_NODE_SSL_VERIFY      = "True"

    # Respect X-* headers to redirect clients
    RESPECT_XFORWARD_HEADERS_ENABLED = false

    # Indexing configuration
    INDEXING_MAX_SEGMENTATION_TOKENS_LENGTH = 4000

    # Plugin configuration
    PLUGIN_DAEMON_URL          = "http://127.0.0.1:5002"
    PLUGIN_REMOTE_INSTALL_PORT = 5003
    PLUGIN_REMOTE_INSTALL_HOST = "localhost"
    PLUGIN_MAX_PACKAGE_SIZE    = 15728640
  }
  dify_api_env = merge(
    local.dify_base_env,
    local.dify_app_env,
    {
      # Startup mode, 'api' starts the API server.
      MODE = "api",
    }
  )
  dify_worker_env = merge(
    local.dify_base_env,
    local.dify_app_env,
    {
      # Startup mode, 'worker' starts the Celery worker for processing the queue.
      MODE = "worker"
    }
  )
  dify_plugin_daemon_env = merge(
    local.dify_base_env,
    {
      # Daemon port
      SERVER_PORT = 5002

      # API Server URL
      DIFY_INNER_API_URL = "http://localhost:5001"

      PLUGIN_REMOTE_INSTALLING_ENABLED = true
      PLUGIN_REMOTE_INSTALLING_HOST    = "localhost"
      PLUGIN_REMOTE_INSTALLING_PORT    = 5003

      # services storage
      PLUGIN_STORAGE_TYPE       = "s3"
      S3_USE_AWS                = true
      S3_USE_AWS_MANAGED_IAM    = true
      PLUGIN_STORAGE_OSS_BUCKET = aws_s3_bucket.plugin_storage.bucket

      # where the plugin finally installed
      PLUGIN_INSTALLED_PATH = "plugin"

      # where the plugin finally running and working
      PLUGIN_WORKING_PATH = "cwd"

      # redis configuration
      REDIS_HOST    = local.redis_serverless_host
      REDIS_PORT    = local.redis_serverless_port
      REDIS_USE_SSL = true
      REDIS_DB      = 0 # use redis db 0 for redis cache

      # PostgreSQL database configuration
      DB_USERNAME = "dify"
      DB_HOST     = aws_rds_cluster.dify.endpoint
      DB_PORT     = aws_rds_cluster.dify.port
      DB_DATABASE = "dify_plugin"
    }
  )
  dify_sandbox_env = {
    GIN_MODE       = "release"
    WORKER_TIMEOUT = 15
    ENABLE_NETWORK = true
    SANDBOX_PORT   = 8194
  }
  dify_web_env = {
    # Console API base URL
    CONSOLE_API_URL = "http://${aws_lb.dify.dns_name}"

    # API APP base URL
    APP_API_URL = "http://${aws_lb.dify.dns_name}"
  }
}
