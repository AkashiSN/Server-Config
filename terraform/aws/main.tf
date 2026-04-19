module "lightsail" {
  source  = "./modules/lightsail"
  project = local.project
}

module "s3_immich" {
  source  = "./modules/s3"
  project = local.project
  purpose = "immich"
}
