resource "aws_eks_cluster" "eks_auto_mode" {
  name     = "${var.project}_eks-auto-mode"
  version  = "1.32"
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
  }

  storage_config {
    block_storage {
      enabled = true
    }
  }

  vpc_config {
    endpoint_private_access = true
    endpoint_public_access  = true

    public_access_cidrs = ["${var.homelab.global_ip_address}/32"]

    subnet_ids         = var.vpc.subnet_ids
    security_group_ids = [aws_security_group.eks_cluster.id]
  }

  tags = {
    Name = "${var.project}_eks-auto-mode"
  }
}

resource "aws_eks_access_entry" "eks_admin" {
  cluster_name  = aws_eks_cluster.eks_auto_mode.name
  principal_arn = "arn:aws:iam::${local.account_id}:user/${var.iam_user}"
  type          = "STANDARD"
}

resource "aws_eks_access_policy_association" "eks_admin" {
  cluster_name  = aws_eks_cluster.eks_auto_mode.name
  principal_arn = "arn:aws:iam::${local.account_id}:user/${var.iam_user}"
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }

  depends_on = [aws_eks_access_entry.eks_admin]
}
