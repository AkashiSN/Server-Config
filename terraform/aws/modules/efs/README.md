# EFS Module

default VPC 上に One Zone EFS を構築し、Lightsail VPC (ピアリング済み) からのみマウントできるようにする Terraform モジュール。

Lightsail インスタンス (`ap-northeast-1a`) と同 AZ に配置することで、低レイテンシ + 低コスト (One Zone は Standard 比 約 1/2) を狙う。

## 前提

- Lightsail と default VPC のピアリングは **手動で構築済み** (Lightsail マネジメントコンソール → アカウント → 詳細設定 → VPC ピアリング)。
- default VPC が当該リージョンに存在し、`var.availability_zone` の AZ にデフォルトサブネットが存在すること。

## リソース構成

| リソース | 説明 |
| --- | --- |
| `data.aws_vpc.default` | default VPC を取得 |
| `data.aws_subnet.default` | default VPC の `${availability_zone}` のデフォルトサブネット |
| `aws_efs_file_system.this` | One Zone EFS (`availability_zone_name` 指定 / `bursting` / `generalPurpose` / 暗号化) |
| `aws_efs_backup_policy.this` | AWS Backup 連携を `DISABLED` で明示 (One Zone はデフォルト有効のため) |
| `aws_efs_mount_target.this` | default VPC サブネットへのマウントターゲット |
| `aws_security_group.this` | EFS 用 SG (default VPC 内) |
| `aws_vpc_security_group_ingress_rule.nfs` | NFS (2049/tcp) を Lightsail CIDR からのみ許可 |

## ライフサイクル

| 遷移 | 設定 |
| --- | --- |
| Standard → IA | 30 日アクセスなしで `AFTER_30_DAYS` |
| IA → Standard | 1 回アクセスで `AFTER_1_ACCESS` (`transition_to_primary_storage_class`) |

> **注意**: `transition_to_archive` (Archive ストレージクラス) は **One Zone EFS では非対応**のため設定していない。

## 変数

| 変数 | 型 | デフォルト | 説明 |
| --- | --- | --- | --- |
| `project` | string | (必須) | リソース名のプレフィックス |
| `availability_zone` | string | `ap-northeast-1a` | One Zone EFS / マウントターゲットを配置する AZ。Lightsail インスタンスと同一にする |
| `lightsail_cidr` | string | `172.26.0.0/16` | NFS イングレスを許可する Lightsail VPC CIDR。ap-northeast-1 では実質固定 |

## 出力

| 出力 | 説明 |
| --- | --- |
| `file_system_id` | EFS file system ID (`fs-xxxxxxxx`) |
| `file_system_dns_name` | `<fs-id>.efs.<region>.amazonaws.com`。**Lightsail からは DNS 解決できない**ため、default VPC 内 EC2 等から使う場合の参考用 |
| `mount_target_ip` | マウントターゲットの ENI プライベート IP。Lightsail からマウントする際はこれを使う |

## マウント手順 (Lightsail から)

Lightsail VPC ピアリングは VPC 間 DNS 解決を相互許可しないため、EFS の DNS 名は解決できない。マウントターゲット IP を直接指定する。

```bash
sudo apt-get install -y nfs-common
sudo mkdir -p /mnt/efs

EFS_IP=$(terraform -chdir=terraform/aws output -raw efs_mount_target_ip)

sudo mount -t nfs4 \
  -o nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport \
  ${EFS_IP}:/ /mnt/efs
```

`/etc/fstab` への永続化は Ansible 側で対応する (本モジュールのスコープ外)。

## 備考

- バックアップは `aws_efs_backup_policy` で明示的に無効化している。必要になったら `status = "ENABLED"` に変更する。
- スループット枯渇 (バーストクレジット切れ) が発生した場合は `throughput_mode = "elastic"` への切替を検討する。
- IPv6 イングレスは設定していない。Lightsail VPC ピアリングは IPv4 のみ。
