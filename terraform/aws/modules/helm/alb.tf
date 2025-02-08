resource "kubernetes_manifest" "ingress_class_params" {
  manifest = provider::kubernetes::manifest_decode(<<EOT
apiVersion: eks.amazonaws.com/v1
kind: IngressClassParams
metadata:
  name: alb
spec:
  scheme: internet-facing
EOT
  )
}

resource "kubernetes_manifest" "ingress_class" {
  manifest = provider::kubernetes::manifest_decode(<<EOT
apiVersion: networking.k8s.io/v1
kind: IngressClass
metadata:
  name: alb
  annotations:
    ingressclass.kubernetes.io/is-default-class: "true"
spec:
  controller: eks.amazonaws.com/alb
  parameters:
    apiGroup: eks.amazonaws.com
    kind: IngressClassParams
    name: alb
EOT
  )
}
