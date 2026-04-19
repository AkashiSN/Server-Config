module "lightsail" {
  source  = "./modules/lightsail"
  project = local.project
}

module "s3ql" {
  source     = "./modules/s3"
  project    = local.project
  purpose    = "s3ql"
  allowed_ip = module.lightsail.k3s_public_ipv4
}
