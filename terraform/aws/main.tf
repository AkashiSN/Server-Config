module "lightsail" {
  source  = "./modules/lightsail"
  project = local.project
}
