module "vpc" {
  source  = "./modules/vpc"
  project = local.project
}
