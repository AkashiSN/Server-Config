terraform {
  required_version = "1.15.1"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.43.0"
    }
  }

  backend "s3" {
    bucket  = "su-nishi"
    region  = "ap-northeast-1"
    key     = "terraform/dev/ap-northeast-1.tfstate"
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
