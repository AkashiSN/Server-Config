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

module "eks" {
  depends_on = [module.vpc]

  source   = "./modules/eks"
  project  = local.project
  iam_user = var.iam_user
  cluster_network = {
    service_cidr = "10.80.0.0/16"
    remote_node_cidrs = [
      "172.16.100.0/24",
      "172.16.254.0/24"
    ]
    remote_pod_cidrs = ["10.85.0.0/16"]
  }
  vpc = {
    id = module.vpc.vpc_id
    subnet_ids = [
      module.vpc.subnet_private_a_id,
      module.vpc.subnet_private_c_id
    ]
  }
}
