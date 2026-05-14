# Lightsail Instance Module

AWS Lightsail 上に汎用的に 1 ノードを構築する Terraform モジュール。`purpose` ごとにインスタンス・追加ディスク・Static IP・キーペア・公開ポートを束ねる。

`user_data` は呼び出し側から `file()` などで inline に渡す形式。現状の呼び出し元は `module.k3s_cluster` ([`terraform/aws/main.tf`](../../main.tf) 参照) で、[`scripts/k3s_node_provisioner.sh`](./scripts/k3s_node_provisioner.sh) を inline で渡している。

## リソース構成

| リソース | 説明 |
| --- | --- |
| `aws_lightsail_key_pair.this` | SSH 鍵ペア (`${project}_${purpose}_key`) |
| `aws_lightsail_instance.this` | Lightsail インスタンス (`${project}_${purpose}`)。blueprint / bundle / AZ / IP 種別は変数で指定 |
| `aws_lightsail_disk.this[<key>]` | `var.disks` の各 key ごとに作る追加ディスク (`${project}_${purpose}-${key}`) |
| `aws_lightsail_disk_attachment.this[<key>]` | 上記ディスクを `var.disks[<key>].disk_path` にアタッチ |
| `aws_lightsail_static_ip.this` | Static IP (`${project}_${purpose}-ip`) |
| `aws_lightsail_static_ip_attachment.this` | インスタンスへのアタッチ。インスタンス再生成時は `replace_triggered_by` で連動 |
| `aws_lightsail_instance_public_ports.this` | `var.ports` から `dynamic "port_info"` で展開した公開ポート設定。インスタンス再生成時は `replace_triggered_by` で連動 |

## 変数

| 変数 | 型 | デフォルト | 説明 |
| --- | --- | --- | --- |
| `project` | string | (必須) | リソース名のプレフィックス |
| `purpose` | string | (必須) | リソース名のサフィックス。user_data URL にも入る |
| `availability_zone` | string | `ap-northeast-1a` | インスタンス / ディスクの AZ |
| `blueprint_id` | string | `ubuntu_24_04` | Lightsail blueprint |
| `bundle_id` | string | (必須) | Lightsail bundle (例: `xlarge_3_0`) |
| `ip_address_type` | string | `dualstack` | `dualstack` / `ipv4` / `ipv6` |
| `user_data` | string | `null` | インスタンスに渡す user_data。`null` のとき下記 `user_data_url` を curl|bash するスクリプトに自動展開 |
| `user_data_url` | string | `null` | curl|bash する URL。`user_data` も `null` のとき、`null` なら `https://akashisn.info/${purpose}_lightsail.sh` |
| `disks` | map(object({size_in_gb, disk_path})) | (必須) | 追加ディスクの map。key は name suffix。空 map で disk なし |
| `ports` | list(object({protocol, from_port, to_port, cidrs, ipv6_cidrs})) | (必須) | 公開ポートのリスト。空リスト可 |

## 出力

| 出力 | 説明 |
| --- | --- |
| `public_ipv4` | Static IPv4 アドレス |
| `public_ipv6` | インスタンスの IPv6 アドレス (`ipv6_addresses[0]`) |
| `private_ipv4` | インスタンスの private IPv4 アドレス |

## 呼び出し例 (`module.k3s_cluster`)

`for_each` で server / agent ノードを束ねて作っている例 ([`terraform/aws/main.tf`](../../main.tf), [`locals.tf`](../../locals.tf))。

```hcl
locals {
  k3s_cluster_nodes = {
    server    = { purpose = "k3s-server",  bundle_id = "medium_3_0", role = "server" }
    "agent-0" = { purpose = "k3s-agent-0", bundle_id = "xlarge_3_0", role = "agent" }
    "agent-1" = { purpose = "k3s-agent-1", bundle_id = "xlarge_3_0", role = "agent" }
  }
}

module "k3s_cluster" {
  for_each = local.k3s_cluster_nodes
  source   = "./modules/lightsail_instance"
  project  = local.project
  purpose  = each.value.purpose

  bundle_id = each.value.bundle_id
  user_data = file("${path.module}/modules/lightsail_instance/scripts/k3s_node_provisioner.sh")

  disks = {}

  ports = concat(
    each.value.role == "agent" ? [
      { protocol = "tcp", from_port = 443, to_port = 443, cidrs = ["0.0.0.0/0"], ipv6_cidrs = ["::/0"] },
    ] : [],
    [
      { protocol = "udp", from_port = 41641, to_port = 41641, cidrs = ["0.0.0.0/0"], ipv6_cidrs = ["::/0"] },
    ],
  )
}
```

ポート設計のポイント:

- 6443 / 8472 / 10250 を **public 開放してはいけない**。kubectl は Tailscale 経由で `--tls-san` に登録した DNS / IP からのみ繋ぐ。
- 443/TCP は ingress-nginx を載せる **agent ノードのみ** 開ける。
- 41641/UDP は tailscale 用に **全ノード** で開ける。
- 22/TCP は初回ブートストラップ時のみ一時的にアンコメントして apply → tailscale / cloudflared 認証 → 再コメントして apply で塞ぐ。

## user_data の中身 (`scripts/k3s_node_provisioner.sh`)

[`scripts/k3s_node_provisioner.sh`](./scripts/k3s_node_provisioner.sh) を `file()` で inline 展開して Lightsail インスタンスの cloud-init に渡す。実行内容は最小:

- `~ubuntu/.ssh/authorized_keys` を `https://github.com/AkashiSN.keys` で上書き
- blueprint デフォルトの `TrustedUserCAKeys` (SSM 用) を無効化
- `apt update && apt upgrade`
- `cloudflared` (Cloudflare APT リポジトリ経由) のインストール
- `tailscale` のインストール (`https://tailscale.com/install.sh`)

k3s 本体 / kernel modules / sysctl / hostname の設定は ansible (`../../../../ansible/setup-k3s-cluster.yml`) で行う。

## クラスタ作成後の手動セットアップ

`user_data` ではパッケージインストールまでしか行わないため、以下は `terraform apply` 後に SSH (初回ブートストラップ用に 22/TCP を一時開放) で各ノードに対して実施する。

### 1. Cloudflare Tunnel の設定

```bash
sudo cloudflared service install <TOKEN>
```

### 2. Tailscale の設定

```bash
sudo tailscale up --auth-key=<TOKEN>
```

両方が完了したら `main.tf` の 22/TCP ブロックを再コメントして `terraform apply` で port を閉じる。以降の SSH / ansible 接続は Tailscale または Cloudflare Tunnel 経由のみ。

### 3. Ansible によるクラスタ構築

```bash
cd ../../ansible
ansible-playbook setup-k3s-cluster.yml
```

詳細は [`../../../../ansible/README.md`](../../../../ansible/README.md) を参照。
