output "eks_cluster_name" {
  value = module.eks.eks_cluster_name
}

output "ssm_activation_id" {
  value = module.eks.ssm_activation_id
}

output "ssm_activation_code" {
  value = module.eks.ssm_activation_code
}
