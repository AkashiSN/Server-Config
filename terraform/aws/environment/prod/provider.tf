# Create s3 bucket
# aws s3api create-bucket --bucket su-nishi-tfstate --region ap-northeast-1 \
#   --create-bucket-configuration LocationConstraint=ap-northeast-1

# aws s3api put-bucket-versioning --bucket su-nishi-tfstate \
#   --versioning-configuration Status=Enabled

terraform {
  required_version = "1.15.3"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.45.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "3.9.0"
    }
  }

  backend "s3" {
    bucket  = "su-nishi-tfstate"
    region  = "ap-northeast-1"
    key     = "terraform/prod/ap-northeast-1.tfstate"
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
