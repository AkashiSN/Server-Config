output "k3s_public_ipv4" {
  value = module.lightsail.k3s_public_ipv4
}

output "k3s_public_ipv6" {
  value = module.lightsail.k3s_public_ipv6
}

output "s3_immich_bucket_name" {
  value = module.s3_immich.bucket_name
}

output "s3_immich_bucket_arn" {
  value = module.s3_immich.bucket_arn
}

output "s3_immich_iam_user_name" {
  value = module.s3_immich.iam_user_name
}

output "s3_immich_iam_access_key_id" {
  value = module.s3_immich.iam_access_key_id
}

output "s3_immich_iam_secret_access_key" {
  value     = module.s3_immich.iam_secret_access_key
  sensitive = true
}
