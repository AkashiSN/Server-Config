module "dev_node" {
  source  = "../../modules/lightsail_instance"
  project = local.project
  purpose = "dev"

  bundle_id = "small_3_0"
  user_data = file("${path.module}/../../modules/lightsail_instance/scripts/dev_node_provisioner.sh")

  disks = {}

  # SSH は Tailscale 経由のみ。public は tailscale (41641) のみ開ける。
  # 22/TCP は初回ブートストラップ時のみ一時開放するため、下のブロックを
  # アンコメントして `terraform apply` → tailscale / cloudflared 認証を済ませ →
  # 再コメント → `terraform apply` で塞ぐ。
  ports = [
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
  ]
}
