# Create Object Storage
# oci os bucket create --versioning Enabled --name snishi-bucket

terraform {
  required_providers {
    oci = {
      source  = "oracle/oci"
      version = "7.22.0"
    }
  }

  backend "oci" {
    bucket    = "snishi-bucket"
    namespace = "nrpl6t6kqy0y"
    key       = "terraform/ap-tokyo-1.tfstate"
  }
}

provider "oci" {
  region = "ap-tokyo-1"
}
