resource "helm_release" "external_dns" {
  name             = "external-dns"
  chart            = "external-dns"
  repository       = "https://kubernetes-sigs.github.io/external-dns/"
  version          = "1.15.0"
  namespace        = "external-dns"
  create_namespace = true
  atomic           = true
  wait             = true
  values = [<<EOT
serviceAccount:
  create: true
  name: external-dns
  annotations:
    eks.amazonaws.com/role-arn: ${var.eks_external_dns_sa_role_arn}
EOT
  ]
}
