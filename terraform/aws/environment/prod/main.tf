module "k3s_cluster" {
  for_each = local.k3s_cluster_nodes
  source   = "../../modules/lightsail_instance"
  project  = local.project
  purpose  = each.value.purpose

  bundle_id = each.value.bundle_id
  user_data = file("${path.module}/../../modules/lightsail_instance/scripts/k3s_node_provisioner.sh")

  disks = {}

  # 6443 / 8472 / 10250 を public 開放してはいけない。kubectl は Tailscale
  # 経由で `--tls-san` に登録した DNS / IP からのみ繋ぐ。443 は ingress-nginx
  # を載せる agent ノードのみ。41641 は tailscale 用に全ノード開けておく。
  #
  # 22/TCP は初回ブートストラップ時のみ一時開放するため、下の {{ }} ブロックを
  # アンコメントして `terraform apply` → tailscale / cloudflared 認証を済ませ →
  # 再コメント → `terraform apply` で塞ぐ。以降の SSH は Tailscale または
  # Cloudflare Tunnel 経由で行う。
  ports = concat(
    each.value.role == "agent" ? [
      {
        protocol   = "tcp"
        from_port  = 443
        to_port    = 443
        cidrs      = ["0.0.0.0/0"]
        ipv6_cidrs = ["::/0"]
      },
    ] : [],
    [
      {
        protocol   = "udp"
        from_port  = 41641
        to_port    = 41641
        cidrs      = ["0.0.0.0/0"]
        ipv6_cidrs = ["::/0"]
      },
      # 初回ブートストラップ用 (使い終わったら再コメント)
      # {
      #   protocol   = "tcp"
      #   from_port  = 22
      #   to_port    = 22
      #   cidrs      = ["0.0.0.0/0"]
      #   ipv6_cidrs = ["::/0"]
      # },
    ],
  )
}


# Lightsail PostgreSQL の master_password は '/', '"', '@', スペースを許可しない。
# Terraform default の特殊文字セットには '@' が含まれるため override が必須。
resource "random_password" "juicefs_db" {
  length           = 32
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

module "lightsail_juicefs_db" {
  source  = "../../modules/lightsail_database"
  project = local.project
  purpose = "juicefs"

  blueprint_id = "postgres_18"
  bundle_id    = "micro_2_0"

  master_database_name = "juicefs"
  master_username      = "juicefs"
  master_password      = random_password.juicefs_db.result
}

module "juicefs_s3" {
  source         = "../../modules/s3"
  project        = local.project
  purpose        = "juicefs"
  allowed_ips    = [for n in module.k3s_cluster : "${n.public_ipv4}/32"]
  admin_iam_user = var.iam_user
}

module "postgres_backup_s3" {
  source          = "../../modules/s3"
  project         = local.project
  purpose         = "postgres-backup"
  allowed_ips     = [for n in module.k3s_cluster : "${n.public_ipv4}/32"]
  admin_iam_user  = var.iam_user
  noncurrent_days = 35
}
