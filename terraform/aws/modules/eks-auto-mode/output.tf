output "eks_cluster_name" {
  value = aws_eks_cluster.eks_auto_mode.name
}

output "eks_cluster_endpoint" {
  value = aws_eks_cluster.eks_auto_mode.endpoint
}

output "eks_cert_manager_sa_role_arn" {
  value = aws_iam_role.cert_manager_sa_role.arn
}
