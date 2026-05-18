# Create s3 bucket (別アカウント側で事前に手動作成)
# aws --profile sylc s3api create-bucket --bucket akashisn-tfstate --region ap-northeast-1 \
#   --create-bucket-configuration LocationConstraint=ap-northeast-1
#
# aws --profile sylc s3api put-bucket-versioning --bucket akashisn-tfstate \
#   --versioning-configuration Status=Enabled

terraform {
  required_version = "1.15.3"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.45.0"
    }
  }

  backend "s3" {
    profile = "sylc"
    bucket  = "akashisn-tfstate"
    region  = "ap-northeast-1"
    key     = "terraform/secrets/ap-northeast-1.tfstate"
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
