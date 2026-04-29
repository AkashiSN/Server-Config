# Lightsail Module

AWS Lightsail 上に k3s シングルノード用のインスタンスを構築する Terraform モジュール。

## リソース構成

| リソース | 説明 |
| --- | --- |
| `aws_lightsail_key_pair.main` | SSH 鍵ペア (`${project}_key`) |
| `aws_lightsail_instance.k3s` | Ubuntu 24.04 / `xlarge_3_0` / ap-northeast-1a / dualstack。`user_data` で `https://akashisn.info/k3s_lightsail.sh` を実行 |
| `aws_lightsail_disk.k3s_zfs` | ZFS 用 128 GB ディスク (ap-northeast-1a) |
| `aws_lightsail_disk_attachment.k3s_zfs` | 上記ディスクをインスタンスの `/dev/xvdf` にアタッチ |
| `aws_lightsail_static_ip.k3s` | Static IP (`${project}_k3s-ip`) |
| `aws_lightsail_static_ip_attachment.k3s` | インスタンスへのアタッチ。インスタンス再生成時は `replace_triggered_by` で連動 |
| `aws_lightsail_instance_public_ports.k3s` | 公開ポート設定 (下表)。インスタンス再生成時は `replace_triggered_by` で連動 |

## 開放ポート

| ポート | プロトコル | 用途 |
| --- | --- | --- |
| 22 | TCP | SSH |
| 53 | UDP | DNS |
| 443 | TCP | HTTPS |
| 853 | TCP | DNS over TLS |
| 51820 | UDP | WireGuard |

すべて `0.0.0.0/0` および `::/0` (IPv6) に開放される。

## 変数

| 変数 | 型 | 説明 |
| --- | --- | --- |
| `project` | string | リソース名のプレフィックス |

## 出力

| 出力 | 説明 |
| --- | --- |
| `k3s_public_ipv4` | Static IPv4 アドレス |
| `k3s_public_ipv6` | インスタンスの IPv6 アドレス (`ipv6_addresses[0]`) |

## user_data で行われる初期化

`user_data` は外部スクリプト `https://akashisn.info/k3s_lightsail.sh` を実行する。元ソースは [`scripts/k3s_provisioner.sh`](./scripts/k3s_provisioner.sh) で、内容は以下のとおり。

- `~ubuntu/.ssh/authorized_keys` を `https://github.com/AkashiSN.keys` で上書き
- `sshd_config` の `TrustedUserCAKeys` を無効化
- ホスト名を `k3s-lightsail` に設定
- `apt update && apt upgrade`
- `cloudflared` (Cloudflare APT リポジトリ経由) のインストール
- `zfsutils-linux`, `zfsnap` のインストール
- `tailscale` のインストール (`https://tailscale.com/install.sh`)
- `net.ipv4.ip_forward` の有効化

## インスタンス作成後の手動セットアップ

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
