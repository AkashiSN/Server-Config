resource "helm_release" "albc" {
  name       = "aws-load-balancer-controller"
  chart      = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  version    = "1.11.0"
  namespace  = "kube-system"

  values = [<<EOT
clusterName: ${var.eks_cluster_name}
region: ap-northeast-1
vpcId: ${var.vpc_id}
serviceAccount:
  create: true
  name: aws-load-balancer-controller
  annotations:
    eks.amazonaws.com/role-arn: ${var.eks_albc_sa_role_arn}
EOT
  ]
}
