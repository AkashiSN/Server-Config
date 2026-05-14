locals {
  project = "su-nishi"

  # 追加ディスクは作らない: bundle root SSD (medium=80GB / xlarge=320GB) で
  # k3s ローカル領域 (containerd image, ephemeral, sqlite) と JuiceFS キャッシュ
  # を賄える。永続データは JuiceFS (S3 backed) に逃がす。
  k3s_cluster_nodes = {
    server = {
      purpose   = "k3s-server"
      bundle_id = "medium_3_0"
      role      = "server"
    }
    "agent-0" = {
      purpose   = "k3s-agent-0"
      bundle_id = "xlarge_3_0"
      role      = "agent"
    }
    "agent-1" = {
      purpose   = "k3s-agent-1"
      bundle_id = "xlarge_3_0"
      role      = "agent"
    }
  }
}
