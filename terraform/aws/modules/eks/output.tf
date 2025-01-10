output "eks_cluster_name" {
  value = aws_eks_cluster.eks_hybrid_nodes.name
}

output "eks_cluster_endpoint" {
  value = aws_eks_cluster.eks_hybrid_nodes.endpoint
}

output "ssm_activation_id" {
  value = aws_ssm_activation.eks_hybrid_nodes.id
}

output "ssm_activation_code" {
  value = aws_ssm_activation.eks_hybrid_nodes.activation_code
}
