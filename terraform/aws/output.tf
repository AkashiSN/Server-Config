output "vpc_id" {
  value = module.vpc.vpc_id
}

# output "eks_hybrid_nodes_cluster_name" {
#   value = module.eks_hybrid_nodes.eks_cluster_name
# }

# output "eks_hybrid_nodes_cluster_endpoint" {
#   value = module.eks_hybrid_nodes.eks_cluster_endpoint
# }

# output "eks_hybrid_nodes_alb_controller_sa_role_arn" {
#   value = module.eks_hybrid_nodes.eks_alb_controller_sa_role_arn
# }

# output "eks_hybrid_nodes_ssm_activation_id" {
#   value = module.eks_hybrid_nodes.ssm_activation_id
# }

# output "eks_hybrid_nodes_ssm_activation_code" {
#   value = module.eks_hybrid_nodes.ssm_activation_code
# }

output "s2s_vpn_private_ipv4" {
  value = module.lightsail.s2s_vpn_private_ipv4
}

output "s2s_vpn_public_ipv4" {
  value = module.lightsail.s2s_vpn_public_ipv4
}

output "s2s_vpn_public_ipv6" {
  value = module.lightsail.s2s_vpn_public_ipv6
}

output "s2s_vpn_wg_pubkey" {
  value = module.lightsail.s2s_vpn_wg_pubkey
}

output "k3s_public_ipv4" {
  value = module.lightsail.k3s_public_ipv4
}

output "k3s_public_ipv6" {
  value = module.lightsail.k3s_public_ipv6
}
