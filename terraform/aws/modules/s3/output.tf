output "bucket_name" {
  value = aws_s3_bucket.this.id
}

output "bucket_arn" {
  value = aws_s3_bucket.this.arn
}

output "bucket_domain_name" {
  value = aws_s3_bucket.this.bucket_regional_domain_name
}

output "iam_user_name" {
  value = aws_iam_user.this.name
}

output "iam_access_key_id" {
  value = aws_iam_access_key.this.id
}

output "iam_secret_access_key" {
  value     = aws_iam_access_key.this.secret
  sensitive = true
}
