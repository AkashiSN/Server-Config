# Lightsail Module

AWS Lightsail上にk3sクラスタ用のインスタンスを構築するTerraformモジュール。

## リソース構成

| リソース | 説明 |
|---|---|
| Lightsail Instance | Ubuntu 24.04 / large_3_0 (ap-northeast-1a) |
| Lightsail Disk | ZFS用 128GB (`/dev/xvdf`) |
| Static IP | デュアルスタック (IPv4 + IPv6) |
| Key Pair | SSH鍵ペア |

## 開放ポート

| ポート | プロトコル | 用途 |
|---|---|---|
| 22 | TCP | SSH |
| 53 | UDP | DNS |
| 443 | TCP | HTTPS |
| 853 | TCP | DNS over TLS |
| 51820 | UDP | WireGuard |

## プロビジョニングで自動設定される項目

- SSH公開鍵の設定 (GitHub keys)
- ホスト名の設定 (`k3s-lightsail`)
- DNSをCloudflare (`1.1.1.1`, `1.0.0.1`) に変更
- `cloudflared`, `zfsutils-linux`, `zfsnap`, `wireguard` のインストール
- WireGuardサーバーキーの生成と初期設定
- IPv4フォワーディングの有効化

なお Immich の写真データは S3QL (S3 バックエンド) 上に保存される。S3QL の
セットアップ (`s3ql`/`fsck.s3ql`/`mount.s3ql` と file descriptor 上限、systemd unit、verify timer 等) は ansible (`roles/common/tasks/s3ql.yml`) 側で実施する。

## インスタンス作成後の手動セットアップ

### 1. Cloudflare Tunnelの設定

```bash
sudo cloudflared service install <TOKEN>
```

### 2. ZFSプールの作成

```bash
sudo zpool create pool /dev/nvme1n1
sudo zfs set compress=lz4 pool
```

### 3. ZFSデータセットの作成

Immich の写真データは S3QL 上にあるため、ここでは ZFS 上に DB 等のみを置く。

```bash
sudo zfs create pool/immich
sudo zfs create pool/immich/immich-postgres
sudo zfs create pool/nextcloud
sudo zfs create pool/nextcloud/nextcloud-app
sudo zfs create pool/nextcloud/nextcloud-mariadb
```

### 4. WireGuardピアの追加

`/etc/wireguard/wg0.conf` を編集してピアを追加する。

### 5. ZFSnapの設定

`/etc/crontab`に以下の設定をする。

```crontab
# 毎時スナップショット（1週間保持）
5  *    * * *   root    /sbin/zfSnap -r -s -S -a 1w pool/immich
# 日次スナップショット（3ヶ月保持）
0  0    * * *   root    /sbin/zfSnap -r -s -S -a 3m pool/immich
# 削除
15 *    * * *   root    /sbin/zfSnap -d
```
