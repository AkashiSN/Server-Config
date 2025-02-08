resource "null_resource" "eks_auto_mode_kubeconfig" {
  triggers = {
    cluster_name = var.eks_cluster_name
  }
  provisioner "local-exec" {
    command = "aws eks update-kubeconfig --kubeconfig ${path.root}/.kubeconfig --name ${var.eks_cluster_name}"
  }
}
