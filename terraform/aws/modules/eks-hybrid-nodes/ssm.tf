resource "aws_ssm_activation" "eks_hybrid_nodes" {
  description        = "EKS Hybrid Nodes Activation"
  iam_role           = aws_iam_role.eks_hybrid_nodes_role.name
  registration_limit = 10
  tags = {
    EKSClusterARN = "arn:aws:eks:ap-northeast-1:${local.account_id}:cluster/${aws_eks_cluster.eks_hybrid_nodes.name}"
  }
}
