data "template_file" "helm_values_cilium" {
  template = file("${path.module}/templates/cilium-values.yml.tftpl")

  vars = {
    cluster_endpoint = data.terraform_remote_state.aws.outputs.eks_cluster_endpoint
  }
}

resource "local_file" "helm_values_cilium" {
  content  = data.template_file.helm_values_cilium.rendered
  filename = "${path.module}/.tmp/cilium-values.yml"
}

data "template_file" "helm_values_alb_controller" {
  template = file("${path.module}/templates/alb-controller-values.yml.tftpl")

  vars = {
    alb_controller_sa_role_arn = data.terraform_remote_state.aws.outputs.eks_alb_controller_sa_role_arn
    cluster_name               = data.terraform_remote_state.aws.outputs.eks_cluster_name
    vpc_id                     = data.terraform_remote_state.aws.outputs.vpc_id
    aws_region                 = "ap-northeast-1"
  }
}

resource "local_file" "helm_values_alb_controller" {
  content  = data.template_file.helm_values_alb_controller.rendered
  filename = "${path.module}/.tmp/alb-controller-values.yml"
}
