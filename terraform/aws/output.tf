output "k3s_public_ipv4" {
  value = module.lightsail_k3s.public_ipv4
}

output "k3s_public_ipv6" {
  value = module.lightsail_k3s.public_ipv6
}

output "s3ql_bucket_name" {
  value = module.s3ql.bucket_name
}

output "s3ql_bucket_arn" {
  value = module.s3ql.bucket_arn
}

output "s3ql_iam_user_name" {
  value = module.s3ql.iam_user_name
}

output "s3ql_iam_access_key_id" {
  value = module.s3ql.iam_access_key_id
}

output "s3ql_iam_secret_access_key" {
  value     = module.s3ql.iam_secret_access_key
  sensitive = true
}

output "juicefs_db_endpoint" {
  value = module.lightsail_juicefs_db.endpoint
}

output "juicefs_db_port" {
  value = module.lightsail_juicefs_db.port
}

output "juicefs_db_engine" {
  value = module.lightsail_juicefs_db.engine
}

output "juicefs_db_engine_version" {
  value = module.lightsail_juicefs_db.engine_version
}

output "juicefs_db_master_username" {
  value = "juicefs"
}

output "juicefs_db_master_password" {
  value     = random_password.juicefs_db.result
  sensitive = true
}

output "juicefs_s3_bucket_name" {
  value = module.juicefs_s3.bucket_name
}

output "juicefs_s3_bucket_arn" {
  value = module.juicefs_s3.bucket_arn
}

output "juicefs_s3_iam_user_name" {
  value = module.juicefs_s3.iam_user_name
}

output "juicefs_s3_iam_access_key_id" {
  value = module.juicefs_s3.iam_access_key_id
}

output "juicefs_s3_iam_secret_access_key" {
  value     = module.juicefs_s3.iam_secret_access_key
  sensitive = true
}
