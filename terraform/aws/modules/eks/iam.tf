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

resource "aws_iam_role" "eks_auto_cluster_role" {
  name               = "${var.project}_role-eks-auto-cluster"
  description        = "Allows access to other AWS service resources that are required to operate Auto Mode clusters managed by EKS."
  assume_role_policy = data.aws_iam_policy_document.eks_auto_cluster_role.json
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

# Amazon EKS Auto node role
data "aws_iam_policy_document" "eks_auto_node_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "eks_auto_node_role" {
  name               = "${var.project}_role-eks-auto-node"
  description        = "Allows EKS nodes to connect to EKS Auto Mode clusters and to pull container images from ECR."
  assume_role_policy = data.aws_iam_policy_document.eks_auto_node_role.json
}

resource "aws_iam_instance_profile" "eks_auto_node_role" {
  name = "${var.project}_role-eks-auto-node"
  role = aws_iam_role.eks_auto_node_role.name
}

resource "aws_iam_role_policy_attachment" "eks_auto_node_role_ecr_pull_policy" {
  role       = aws_iam_role.eks_auto_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPullOnly"
}

resource "aws_iam_role_policy_attachment" "eks_auto_node_role_worker_policy" {
  role       = aws_iam_role.eks_auto_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodeMinimalPolicy"
}

# Hybrid Nodes IAM role
data "aws_iam_policy_document" "eks_hybrid_node_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ssm.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "eks_hybrid_node_role" {
  name               = "${var.project}_role-eks-hybrid-node"
  assume_role_policy = data.aws_iam_policy_document.eks_hybrid_node_role.json
}

data "aws_iam_policy_document" "eks_describe_cluster_policy" {
  statement {
    actions   = ["eks:DescribeCluster"]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "eks_describe_cluster_policy" {
  name   = "EKSDescribeClusterPolicy"
  role   = aws_iam_role.eks_hybrid_node_role.name
  policy = data.aws_iam_policy_document.eks_describe_cluster_policy.json
}

data "aws_iam_policy_document" "eks_hybrid_ssm_policy" {
  statement {
    actions = [
      "ssm:DescribeInstanceInformation",
      "ssm:DeregisterManagedInstance"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "eks_hybrid_ssm_policy" {
  name   = "EKSHybridSSMPolicy"
  role   = aws_iam_role.eks_hybrid_node_role.name
  policy = data.aws_iam_policy_document.eks_hybrid_ssm_policy.json
}

resource "aws_iam_role_policy_attachment" "eks_hybrid_node_role_ecr_pull_policy" {
  role       = aws_iam_role.eks_hybrid_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPullOnly"
}

resource "aws_iam_role_policy_attachment" "eks_hybrid_node_role_ssm_policy" {
  role       = aws_iam_role.eks_hybrid_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}
