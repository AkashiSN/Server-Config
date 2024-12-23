output "subnet_private_a_id" {
  value = aws_subnet.private_a.id
}

output "subnet_private_c_id" {
  value = aws_subnet.private_c.id
}

output "sg_eks_cluster_id" {
  value = aws_security_group.eks_cluster.id
}

output "sg_eks_workernode_id" {
  value = aws_security_group.eks_workernode.id
}
