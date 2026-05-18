output "k3s_cluster" {
  description = "k3s クラスタの各 Lightsail インスタンス情報 (キーは local.k3s_cluster_nodes のキー: server / agent-0 / agent-1)"
  value = {
    for k, n in module.k3s_cluster : k => {
      instance_name = n.instance_name
      public_ipv4   = n.public_ipv4
      public_ipv6   = n.public_ipv6
      private_ipv4  = n.private_ipv4
    }
  }
}

output "juicefs_db" {
  description = "JuiceFS メタデータ用 Lightsail PostgreSQL の接続情報 (master_password を含むため全体 sensitive)"
  sensitive   = true
  value = {
    endpoint        = module.lightsail_juicefs_db.endpoint
    port            = module.lightsail_juicefs_db.port
    engine          = module.lightsail_juicefs_db.engine
    engine_version  = module.lightsail_juicefs_db.engine_version
    master_username = "juicefs"
    master_password = random_password.juicefs_db.result
  }
}

output "juicefs_s3" {
  description = "JuiceFS object storage 用 S3 バケットと IAM ユーザ (iam_secret_access_key を含むため全体 sensitive)"
  sensitive   = true
  value = {
    bucket_name           = module.juicefs_s3.bucket_name
    bucket_arn            = module.juicefs_s3.bucket_arn
    iam_user_name         = module.juicefs_s3.iam_user_name
    iam_access_key_id     = module.juicefs_s3.iam_access_key_id
    iam_secret_access_key = module.juicefs_s3.iam_secret_access_key
  }
}

output "postgres_backup_s3" {
  description = "Postgres WAL-G バックアップ用 S3 バケットと IAM ユーザ (iam_secret_access_key を含むため全体 sensitive)"
  sensitive   = true
  value = {
    bucket_name           = module.postgres_backup_s3.bucket_name
    bucket_arn            = module.postgres_backup_s3.bucket_arn
    iam_user_name         = module.postgres_backup_s3.iam_user_name
    iam_access_key_id     = module.postgres_backup_s3.iam_access_key_id
    iam_secret_access_key = module.postgres_backup_s3.iam_secret_access_key
  }
}
