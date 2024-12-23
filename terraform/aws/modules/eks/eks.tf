resource "aws_eks_cluster" "eks_hybrid_nodes" {
  name     = "${var.project}_eks-hybrid-nodes"
  version  = "1.31"
  role_arn = aws_iam_role.eks_auto_cluster_role.arn

  bootstrap_self_managed_addons = false

  access_config {
    authentication_mode = "API"
  }

  compute_config {
    enabled       = true
    node_pools    = ["general-purpose", "system"]
    node_role_arn = aws_iam_role.eks_auto_nodes_role.arn
  }

  kubernetes_network_config {
    elastic_load_balancing {
      enabled = true
    }
    service_ipv4_cidr = var.network.service_cidr
  }

  storage_config {
    block_storage {
      enabled = true
    }
  }

  remote_network_config {
    remote_node_networks {
      cidrs = var.network.remote_node_cidrs
    }
    remote_pod_networks {
      cidrs = var.network.remote_pod_cidrs
    }
  }

  vpc_config {
    endpoint_private_access = true
    endpoint_public_access  = false

    subnet_ids         = var.vpc.subnet_ids
    security_group_ids = var.vpc.sg_ids
  }

  tags = {
    Name = "${var.project}_eks-hybrid-nodes"
  }
}

resource "aws_eks_access_entry" "eks_admin" {
  cluster_name  = aws_eks_cluster.eks_hybrid_nodes.name
  principal_arn = data.aws_iam_user.current.arn
  type          = "STANDARD"
}

resource "aws_eks_access_policy_association" "eks_admin" {
  cluster_name  = aws_eks_cluster.eks_hybrid_nodes.name
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
  principal_arn = data.aws_iam_user.current.arn

  access_scope {
    type = "cluster"
  }

  depends_on = [aws_eks_access_entry.eks_admin]
}

resource "aws_eks_access_entry" "eks_hybrid_nodes" {
  cluster_name  = aws_eks_cluster.eks_hybrid_nodes.name
  principal_arn = aws_iam_role.eks_hybrid_nodes_role.arn
  type          = "HYBRID_LINUX"
}
