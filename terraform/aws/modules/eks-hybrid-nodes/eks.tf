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
    service_ipv4_cidr = var.cluster_network.service_cidr
    elastic_load_balancing {
      enabled = true
    }
  }

  storage_config {
    block_storage {
      enabled = true
    }
  }

  remote_network_config {
    remote_node_networks {
      cidrs = var.cluster_network.remote_node_cidrs
    }
    remote_pod_networks {
      cidrs = var.cluster_network.remote_pod_cidrs
    }
  }

  vpc_config {
    endpoint_private_access = true
    endpoint_public_access  = false

    subnet_ids         = var.vpc.subnet_ids
    security_group_ids = [aws_security_group.eks_cluster.id]
  }

  tags = {
    Name = "${var.project}_eks-hybrid-nodes"
  }
}

resource "aws_eks_access_entry" "eks_admin" {
  cluster_name  = aws_eks_cluster.eks_hybrid_nodes.name
  principal_arn = "arn:aws:iam::${local.account_id}:user/${var.iam_user}"
  type          = "STANDARD"
}

resource "aws_eks_access_policy_association" "eks_admin" {
  cluster_name  = aws_eks_cluster.eks_hybrid_nodes.name
  principal_arn = "arn:aws:iam::${local.account_id}:user/${var.iam_user}"
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

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

data "tls_certificate" "eks_hybrid_nodes" {
  url = aws_eks_cluster.eks_hybrid_nodes.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "eks_hybrid_nodes" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = data.tls_certificate.eks_hybrid_nodes.certificates[*].sha1_fingerprint
  url             = data.tls_certificate.eks_hybrid_nodes.url
  tags = {
    eks_cluster = aws_eks_cluster.eks_hybrid_nodes.name
  }
}
