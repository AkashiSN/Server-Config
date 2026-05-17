terraform {
  required_version = "1.15.1"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.43.0"
    }
  }

  # 別アカウントの S3 バケット (versioning + encrypt 有効で事前作成しておく)。
  # 別アカウントへの認証は .envrc の AWS_PROFILE で切り替える。
  backend "s3" {
    bucket  = "<別アカウントのバケット名>"
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
