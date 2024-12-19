# Create s3 bucket
# aws s3api create-bucket --bucket su-nishi-bucket --region ap-northeast-1 \
#   --create-bucket-configuration LocationConstraint=ap-northeast-1

# aws s3api put-bucket-versioning --bucket su-nishi-bucket \
#   --versioning-configuration Status=Enabled

# Create dynamodb
# aws dynamodb create-table \
#   --region ap-northeast-1 \
#   --table-name su-nishi-table \
#   --attribute-definitions AttributeName=LockID,AttributeType=S \
#   --key-schema AttributeName=LockID,KeyType=HASH \
#   --provisioned-throughput ReadCapacityUnits=1,WriteCapacityUnits=1

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.81.0"
    }
  }

  backend "s3" {
    bucket         = "su-nishi-bucket"
    region         = "ap-northeast-1"
    key            = "terraform/ap-northeast-1.tfstate"
    dynamodb_table = "su-nishi-table"
    encrypt        = true
  }
}

provider "aws" {
  region = "ap-northeast-1"
}
