output "vpc_id" {
  value = module.vpc.vpc_id
}

output "eks_cluster_name" {
  value = module.eks.eks_cluster_name
}

output "eks_cluster_endpoint" {
  value = module.eks.eks_cluster_endpoint
}

output "eks_alb_controller_sa_role_arn" {
  value = module.eks.eks_alb_controller_sa_role_arn
}

output "ssm_activation_id" {
  value = module.eks.ssm_activation_id
}

output "ssm_activation_code" {
  value = module.eks.ssm_activation_code
}
