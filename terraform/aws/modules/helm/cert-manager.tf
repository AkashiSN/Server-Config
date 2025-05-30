resource "local_file" "cert_manager_cluster_issuer" {
  content = templatefile("${path.module}/template/clusterissuer-lets-encrypt-${var.target_env}.yml.tfpl", {
    email                        = var.email
    host_zone_id                 = var.host_zone_id
    eks_cert_manager_sa_role_arn = var.eks_cert_manager_sa_role_arn
  })

  filename   = "${path.module}/.tmp/clusterissuer-lets-encrypt-${var.target_env}.yml"
  depends_on = [helm_release.cert_manager]
}

resource "null_resource" "cert_manager_cluster_issuer" {
  triggers = {
    manifest_hash = local_file.cert_manager_cluster_issuer.content_sha256
  }
  provisioner "local-exec" {
    command = "kubectl --kubeconfig ${path.root}/.kubeconfig apply -f ${local_file.cert_manager_cluster_issuer.filename}"
  }
}
