output "vpc_id" {
  value = module.vpc.vpc_id
}

output "eks_cluster_name" {
  value = module.eks.eks_cluster_name
}

output "eks_cluster_endpoint" {
  value = module.eks.eks_cluster_endpoint
}

output "ssm_activation_id" {
  value = module.eks.ssm_activation_id
}

output "ssm_activation_code" {
  value = module.eks.ssm_activation_code
}
