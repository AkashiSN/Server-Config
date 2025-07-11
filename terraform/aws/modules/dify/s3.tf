# S3 Bucket for Dify Storage
resource "aws_s3_bucket" "storage" {
  bucket = "${var.project}-dify-storage"
}
