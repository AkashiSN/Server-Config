output "eks_cluster_name" {
  value = aws_eks_cluster.eks_auto_mode.name
}

output "eks_cluster_endpoint" {
  value = aws_eks_cluster.eks_auto_mode.endpoint
}
