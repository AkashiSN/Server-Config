# Lightsail Instance Module

AWS Lightsail 上に汎用的に 1 ノードを構築する Terraform モジュール。`purpose` ごとにインスタンス・追加ディスク・Static IP・キーペア・公開ポートを束ねる。

`user_data` は `https://akashisn.info/${purpose}_lightsail.sh` を curl|bash する形になっており、公開リポジトリ ([AkashiSN.github.io](https://github.com/AkashiSN/AkashiSN.github.io)) に置かれた `<purpose>_lightsail.sh` ラッパーが本リポジトリの `scripts/<purpose>_provisioner.sh` を取得して実行する。現状の用途は `purpose=k3s` のみ。

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
| `user_data_url` | string | `null` | curl|bash する URL。`null` のとき `https://akashisn.info/${purpose}_lightsail.sh` |
| `disks` | map(object({size_in_gb, disk_path})) | (必須) | 追加ディスクの map。key は name suffix。空 map で disk なし |
| `ports` | list(object({protocol, from_port, to_port, cidrs, ipv6_cidrs})) | (必須) | 公開ポートのリスト。空リスト可 |

## 出力

| 出力 | 説明 |
| --- | --- |
| `public_ipv4` | Static IPv4 アドレス |
| `public_ipv6` | インスタンスの IPv6 アドレス (`ipv6_addresses[0]`) |

## 呼び出し例 (purpose=k3s)

```hcl
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
    { protocol = "udp", from_port = 53, to_port = 53, cidrs = ["0.0.0.0/0"], ipv6_cidrs = ["::/0"] },
    { protocol = "tcp", from_port = 443, to_port = 443, cidrs = ["0.0.0.0/0"], ipv6_cidrs = ["::/0"] },
    { protocol = "tcp", from_port = 853, to_port = 853, cidrs = ["0.0.0.0/0"], ipv6_cidrs = ["::/0"] },
    { protocol = "udp", from_port = 51820, to_port = 51820, cidrs = ["0.0.0.0/0"], ipv6_cidrs = ["::/0"] },
  ]
}
```

## k3s 用 user_data の中身 (`scripts/k3s_provisioner.sh`)

公開ラッパー `https://akashisn.info/k3s_lightsail.sh` から本リポジトリの [`scripts/k3s_provisioner.sh`](./scripts/k3s_provisioner.sh) が curl|bash される。内容は以下のとおり。

- `~ubuntu/.ssh/authorized_keys` を `https://github.com/AkashiSN.keys` で上書き
- `sshd_config` の `TrustedUserCAKeys` を無効化
- ホスト名を `k3s-lightsail` に設定
- `apt update && apt upgrade`
- `cloudflared` (Cloudflare APT リポジトリ経由) のインストール
- `zfsutils-linux`, `zfsnap` のインストール
- `tailscale` のインストール (`https://tailscale.com/install.sh`)
- `net.ipv4.ip_forward` の有効化

## k3s 用インスタンス作成後の手動セットアップ

`user_data` ではパッケージインストールまでしか行わないため、以下は `terraform apply` 後に SSH で実施する。

### 1. Cloudflare Tunnel の設定

```bash
sudo cloudflared service install <TOKEN>
```

### 2. Tailscale の設定

```bash
sudo tailscale up --auth-key=<TOKEN>
```

### 3. ZFS プールの作成

追加ディスク (`/dev/xvdf` → 実デバイス名は `nvme1n1` 等) を `pool` として作成する。

```bash
sudo zpool create pool /dev/nvme1n1
sudo zfs set compress=lz4 pool
```

### 4. ZFS データセットの作成

Immich の写真データと Nextcloud のユーザデータは S3QL 上に置くため、ここでは ZFS 上に DB / app データのみ作成する。

```bash
sudo zfs create pool/immich
sudo zfs create pool/immich/immich-postgres
sudo zfs create pool/nextcloud
sudo zfs create pool/nextcloud/nextcloud-app
sudo zfs create pool/nextcloud/nextcloud-postgres
```

### 5. ZFSnap の設定

`/etc/crontab` に以下を追記する。

```crontab
# 毎時スナップショット (1 週間保持)
5  *    * * *   root    /sbin/zfSnap -r -s -S -a 1w pool/immich
# 日次スナップショット (3 ヶ月保持)
0  0    * * *   root    /sbin/zfSnap -r -s -S -a 3m pool/immich
# 削除
15 *    * * *   root    /sbin/zfSnap -d
```
