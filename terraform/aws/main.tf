module "vpc" {
  source  = "./modules/vpc"
  project = local.project
  homelab = {
    global_ip_address = var.homelab_global_ip_address
  }
}

module "ec2" {
  source  = "./modules/ec2"
  project = local.project
}
