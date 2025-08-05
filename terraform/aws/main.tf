module "vpc" {
  source  = "./modules/vpc"
  project = local.project
}

# module "route53" {
#   source = "./modules/route53"
# }

# module "ecr" {
#   source = "./modules/ecr"
# }

# module "kms" {
#   source   = "./modules/kms"
#   project  = local.project
#   iam_user = var.iam_user
# }

# module "efs" {
#   source      = "./modules/efs"
#   project     = local.project
#   kms_key_arn = module.kms.kms_key_arn
#   vpc = {
#     id        = module.vpc.vpc_id
#     cidr      = module.vpc.vpc_cidr
#     subnet_id = module.vpc.subnet_private_a_id
#   }
# }

# module "vpn" {
#   source  = "./modules/vpn"
#   project = local.project
#   homelab = {
#     global_ip_address = var.homelab_global_ip_address
#   }
#   vpc = {
#     id = module.vpc.vpc_id
#     route_table_id = {
#       main      = module.vpc.route_table_main_id
#       private_a = module.vpc.route_table_private_a_id
#       private_c = module.vpc.route_table_private_c_id
#     }
#   }
# }

module "ec2" {
  source  = "./modules/ec2"
  project = local.project
}

# module "eks_hybrid_nodes" {
#   source   = "./modules/eks-hybrid-nodes"
#   project  = local.project
#   iam_user = var.iam_user
#   cluster_network = {
#     service_cidr = "10.80.0.0/16"
#     remote_node_cidrs = [
#       "172.16.100.0/24",
#       "172.16.254.0/24"
#     ]
#     remote_pod_cidrs = ["10.85.0.0/16"]
#   }
#   vpc = {
#     id = module.vpc.vpc_id
#     subnet_ids = [
#       module.vpc.subnet_private_a_id,
#       module.vpc.subnet_private_c_id
#     ]
#   }
# }

# module "eks_auto_mode" {
#   source   = "./modules/eks-auto-mode"
#   project  = local.project
#   iam_user = var.iam_user
#   homelab = {
#     global_ip_address = var.homelab_global_ip_address
#   }
#   vpc = {
#     id = module.vpc.vpc_id
#     subnet_ids = [
#       module.vpc.subnet_private_a_id,
#       module.vpc.subnet_private_c_id
#     ]
#   }
# }

# module "helm" {
#   source                       = "./modules/helm"
#   email                        = var.email
#   vpc_id                       = module.vpc.vpc_id
#   eks_cluster_name             = module.eks_auto_mode.eks_cluster_name
#   eks_cert_manager_sa_role_arn = module.eks_auto_mode.eks_cert_manager_sa_role_arn
#   eks_external_dns_sa_role_arn = module.eks_auto_mode.eks_external_dns_sa_role_arn
#   host_zone_id                 = module.route53.host_zone_id
#   target_env                   = "production" # staging or production
# }

module "lightsail" {
  source  = "./modules/lightsail"
  project = local.project
}

# module "dify" {
#   source  = "./modules/dify"
#   project = local.project
#   vpc = {
#     id = module.vpc.vpc_id
#     private_subnet_ids = [
#       module.vpc.subnet_private_a_id,
#       module.vpc.subnet_private_c_id
#     ]
#     public_subnet_ids = [
#       module.vpc.subnet_public_a_id,
#       module.vpc.subnet_public_c_id
#     ]
#   }
# }
