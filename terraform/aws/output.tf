output "k3s_public_ipv4" {
  value = module.lightsail.k3s_public_ipv4
}

output "k3s_public_ipv6" {
  value = module.lightsail.k3s_public_ipv6
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
