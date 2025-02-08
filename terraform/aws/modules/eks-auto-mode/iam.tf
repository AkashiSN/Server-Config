# Amazon EKS Auto cluster role
data "aws_iam_policy_document" "eks_auto_cluster_role" {
  statement {
    actions = ["sts:AssumeRole", "sts:TagSession"]
    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }
  }
}

locals {
  eks_auto_cluster_role_json = data.aws_iam_policy_document.eks_auto_cluster_role.json
}

resource "aws_iam_role" "eks_auto_cluster_role" {
  name               = "${var.project}_role-eks-auto-cluster"
  description        = "Allows access to other AWS service resources that are required to operate Auto Mode clusters managed by EKS."
  assume_role_policy = local.eks_auto_cluster_role_json
}

resource "aws_iam_role_policy_attachment" "eks_auto_cluster_role_cluster_policy" {
  role       = aws_iam_role.eks_auto_cluster_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

resource "aws_iam_role_policy_attachment" "eks_auto_cluster_role_compute_policy" {
  role       = aws_iam_role.eks_auto_cluster_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSComputePolicy"
}

resource "aws_iam_role_policy_attachment" "eks_auto_cluster_role_storage_policy" {
  role       = aws_iam_role.eks_auto_cluster_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSBlockStoragePolicy"
}

resource "aws_iam_role_policy_attachment" "eks_auto_cluster_role_lb_policy" {
  role       = aws_iam_role.eks_auto_cluster_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSLoadBalancingPolicy"
}

resource "aws_iam_role_policy_attachment" "eks_auto_cluster_role_nw_policy" {
  role       = aws_iam_role.eks_auto_cluster_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSNetworkingPolicy"
}


# Amazon EKS Auto nodes role
data "aws_iam_policy_document" "eks_auto_nodes_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

locals {
  eks_auto_nodes_role_json = data.aws_iam_policy_document.eks_auto_nodes_role.json
}

resource "aws_iam_role" "eks_auto_nodes_role" {
  name               = "${var.project}_role-eks-auto-nodes"
  description        = "Allows EKS nodes to connect to EKS Auto Mode clusters and to pull container images from ECR."
  assume_role_policy = local.eks_auto_nodes_role_json
}

resource "aws_iam_instance_profile" "eks_auto_nodes_role" {
  name = "${var.project}_role-eks-auto-nodes"
  role = aws_iam_role.eks_auto_nodes_role.name
}

resource "aws_iam_role_policy_attachment" "eks_auto_nodes_role_ecr_pull_policy" {
  role       = aws_iam_role.eks_auto_nodes_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPullOnly"
}

resource "aws_iam_role_policy_attachment" "eks_auto_nodes_role_worker_policy" {
  role       = aws_iam_role.eks_auto_nodes_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodeMinimalPolicy"
}


# ALB controller service account IAM role
data "tls_certificate" "eks_auto_mode" {
  url = aws_eks_cluster.eks_auto_mode.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "eks_auto_mode" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = data.tls_certificate.eks_auto_mode.certificates[*].sha1_fingerprint
  url             = data.tls_certificate.eks_auto_mode.url
  tags = {
    eks_cluster = aws_eks_cluster.eks_auto_mode.name
  }
}

data "aws_iam_policy_document" "eks_albc_sa_role" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.eks_auto_mode.arn]
    }
    condition {
      test     = "StringEquals"
      variable = "${trimprefix(aws_iam_openid_connect_provider.eks_auto_mode.url, "https://")}:aud"
      values   = ["sts.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "${trimprefix(aws_iam_openid_connect_provider.eks_auto_mode.url, "https://")}:sub"
      values   = ["system:serviceaccount:kube-system:aws-load-balancer-controller"]
    }
  }
}

locals {
  eks_albc_sa_role_json = data.aws_iam_policy_document.eks_albc_sa_role.json
}

resource "aws_iam_role" "eks_albc_sa_role" {
  name               = "${var.project}_role-eks-alb-controller-sa"
  assume_role_policy = local.eks_albc_sa_role_json
}

resource "aws_iam_policy" "eks_albc_sa_policy" {
  name = "${var.project}_policy-eks-alb-controller-sa"
  # https://github.com/kubernetes-sigs/aws-load-balancer-controller/blob/main/docs/install/iam_policy.json
  policy = file("${path.module}/files/albc_policy.json")
}

resource "aws_iam_role_policy_attachment" "eks_albc_sa_policy" {
  role       = aws_iam_role.eks_albc_sa_role.name
  policy_arn = aws_iam_policy.eks_albc_sa_policy.arn
}
