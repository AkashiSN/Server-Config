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
  allowed_ip     = module.lightsail_k3s.public_ipv4
  admin_iam_user = var.iam_user
}
