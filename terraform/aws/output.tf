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
