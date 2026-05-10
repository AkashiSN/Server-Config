module "lightsail_k3s" {
  source  = "./modules/lightsail_instance"
  project = local.project
  purpose = "k3s"

  bundle_id = "xlarge_3_0"

  disks = {
    zfs = {
      size_in_gb = 128
      disk_path  = "/dev/xvdf"
    }
  }

  ports = [
    {
      protocol   = "udp"
      from_port  = 53
      to_port    = 53
      cidrs      = ["0.0.0.0/0"]
      ipv6_cidrs = ["::/0"]
    },
    {
      protocol   = "tcp"
      from_port  = 443
      to_port    = 443
      cidrs      = ["0.0.0.0/0"]
      ipv6_cidrs = ["::/0"]
    },
    {
      protocol   = "tcp"
      from_port  = 853
      to_port    = 853
      cidrs      = ["0.0.0.0/0"]
      ipv6_cidrs = ["::/0"]
    },
    {
      protocol   = "udp"
      from_port  = 51820
      to_port    = 51820
      cidrs      = ["0.0.0.0/0"]
      ipv6_cidrs = ["::/0"]
    },
  ]
}

module "s3ql" {
  source         = "./modules/s3"
  project        = local.project
  purpose        = "s3ql"
  allowed_ips    = ["${module.lightsail.k3s_public_ipv4}/32"]
  admin_iam_user = var.iam_user
}

# Lightsail PostgreSQL の master_password は '/', '"', '@', スペースを許可しない。
# Terraform default の特殊文字セットには '@' が含まれるため override が必須。
resource "random_password" "juicefs_db" {
  length           = 32
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

module "lightsail_juicefs_db" {
  source  = "./modules/lightsail_database"
  project = local.project
  purpose = "juicefs"

  blueprint_id = "postgres_18"
  bundle_id    = "micro_2_0"

  master_database_name = "juicefs"
  master_username      = "juicefs"
  master_password      = random_password.juicefs_db.result
}

module "juicefs_s3" {
  source         = "./modules/s3"
  project        = local.project
  purpose        = "juicefs"
  allowed_ips    = ["${module.lightsail.k3s_public_ipv4}/32"]
  admin_iam_user = var.iam_user
}
