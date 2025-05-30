resource "aws_eks_cluster" "eks_auto_mode" {
  name     = "${var.project}_eks-v133-auto-mode"
  version  = "1.33"
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

resource "aws_eks_addon" "eks_pod_identity_agent" {
  cluster_name  = aws_eks_cluster.eks_auto_mode.name
  addon_name    = "eks-pod-identity-agent"
  addon_version = "v1.3.7-eksbuild.2"
}

resource "aws_eks_addon" "external_dns" {
  cluster_name  = aws_eks_cluster.eks_auto_mode.name
  addon_name    = "external-dns"
  addon_version = "v0.17.0-eksbuild.1"
  pod_identity_association {
    role_arn        = aws_iam_role.external_dns_sa_role.arn
    service_account = "external-dns"
  }
  depends_on = [aws_eks_addon.eks_pod_identity_agent]
}

resource "aws_eks_addon" "cert_manager" {
  cluster_name             = aws_eks_cluster.eks_auto_mode.name
  addon_name               = "cert-manager"
  addon_version            = "v1.17.2-eksbuild.1"
  service_account_role_arn = aws_iam_role.cert_manager_sa_role.arn
  depends_on               = [aws_eks_addon.eks_pod_identity_agent]
}

resource "aws_eks_addon" "metrics_server" {
  cluster_name  = aws_eks_cluster.eks_auto_mode.name
  addon_name    = "metrics-server"
  addon_version = "v0.7.2-eksbuild.3"
  depends_on    = [aws_eks_addon.eks_pod_identity_agent]
}
