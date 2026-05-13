locals {
  project = "su-nishi"

  # New multi-node k3s cluster (server x1 + agent x2) that runs in parallel
  # with the legacy single-node `lightsail_k3s` (k3s-vps) until migration is
  # complete. The provisioner script is passed inline as user_data and does
  # NOT install k3s itself - ansible handles the cluster join.

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
