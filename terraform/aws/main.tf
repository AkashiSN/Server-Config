# module "vpc" {
#   source  = "./modules/vpc"
#   project = local.project
# }

# module "ec2" {
#   source  = "./modules/ec2"
#   project = local.project
# }

module "lightsail" {
  source  = "./modules/lightsail"
  project = local.project
}
