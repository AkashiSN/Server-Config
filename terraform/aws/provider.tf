# Create s3 bucket
# aws s3api create-bucket --bucket su-nishi-bucket --region ap-northeast-1 \
#   --create-bucket-configuration LocationConstraint=ap-northeast-1

# aws s3api put-bucket-versioning --bucket su-nishi-bucket \
#   --versioning-configuration Status=Enabled

terraform {
  required_version = "1.14.3"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.30.0"
    }
  }

  backend "s3" {
    bucket  = "su-nishi-bucket"
    region  = "ap-northeast-1"
    key     = "terraform/ap-northeast-1.tfstate"
    encrypt = true
  }
}

provider "aws" {
  region = "ap-northeast-1"

  default_tags {
    tags = {
      CreatedBy = var.iam_user
    }
  }
}
