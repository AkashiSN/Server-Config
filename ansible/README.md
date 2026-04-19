# Ansible

k3s-vps ホスト (Ubuntu 24.04) を k3s クラスタとしてプロビジョニングします。

## Prerequisites

- Ubuntu 24.04 のターゲットホストに SSH で到達できること
- ローカルに ansible / ansible-playbook がインストール済みであること
- [1Password CLI (`op`)](https://developer.1password.com/docs/cli/) にサインイン済みで、`op://Private/ansible-vault/password` および `op://Private/ansible-vault/vault.yml` にアクセスできること
- Ansible collections のインストール

  ```bash
  ansible-galaxy collection install -r requirements.yml
  ```

## Layout

| パス | 役割 |
| --- | --- |
| `ansible.cfg` | inventory / vault パスワードファイル / python interpreter の設定 |
| `inventory.yml` | `k3s-vps` ホスト定義 (`ansible_host: k3s-oci.akashisn.info`) |
| `vault-pass.sh` | 1Password から vault パスワードを読み取るスクリプト (`ansible.cfg` から参照) |
| `requirements.yml` | 必要な Ansible collections (`community.general`, `kubernetes.core`) |
| `setup-k3s-vps.yml` | `common` → `cluster` ロールを順に実行する playbook |
| `host_vars/k3s-vps/vars.yml` | ドメイン / k3s ノードラベル / oauth2-proxy / argo-cd 設定などの変数 |
| `host_vars/k3s-vps/vault.yml` | 暗号化済み秘密値 (`make credential` で取得) |
| `roles/variable/` | 共通変数 (cloudflare IP レンジや `external_ip` の取得) |
| `roles/common/` | OS 基本設定: timezone, swap, logrotate, kernel sysctl, helm, dns, k3s server インストール |
| `roles/cluster/` | クラスタ内 Helm リリース: ingress-nginx, cert-manager, oauth2-proxy, argo-cd, secrets, storage-class |

## Usage

### 1. Vault credential 取得

1Password から `host_vars/k3s-vps/vault.yml` をローカルに取得します。

```bash
make credential
```

### 2. プロビジョニング実行

```bash
make k3s-vps
```

内部で `ansible-playbook setup-k3s-vps.yml` を実行します。`vault-pass.sh` 経由で vault が復号されるため、事前に `op` のサインインが必要です。

### 3. ローカル credential の掃除

```bash
make clean
```

`host_vars/k3s-vps/vault.yml` を削除します（リポジトリ外に漏らさない用）。

## s3ql (Immich 写真用) セットアップ

Immich の `immich-photos` PV は `/mnt/s3ql/immich-photos` に s3ql でマウントした AWS S3 バケット (`module.s3_immich`) を使います。ansible 実行前に以下の準備が必要です。

### 1. 1Password → vault.yml に登録

以下のキーを `host_vars/k3s-vps/vault.yml` に追加します (1Password 側にも反映)。

| キー | 値 |
| --- | --- |
| `vault_s3ql_aws_access_key_id` | IAM アクセスキー |
| `vault_s3ql_aws_secret_access_key` | IAM シークレットキー |
| `vault_s3ql_fs_passphrase` | 生成したパスフレーズ |
| `vault_s3ql_bucket_url` | `s3://<project>-immich-bucket/s3ql` |

### 2. 初回のみ `mkfs.s3ql` を手動実行

ansible は `mkfs.s3ql` を実行しません。初回実行時（および s3ql バージョンアップ直後）はサービスの `started` ステートをスキップするため、mkfs 後に手動で起動します。

```bash
# 一度 ansible を流して s3ql をインストールし、authinfo2 と systemd unit を配置する
make k3s-vps

# k3s-vps ノードに SSH して mkfs（初回 1 回だけ）
sudo /usr/local/bin/mkfs.s3ql --authfile /root/.s3ql/authinfo2 s3://<project>-immich-bucket
sudo systemctl start s3ql-immich.service
```

以降は `make k3s-vps` を流すだけで `s3ql-immich.service` が冪等に維持されます。

## Notes

- Kubernetes 上のアプリ (dns / nextcloud / immich など) は [`../kubernetes/`](../kubernetes/README.md) 側で管理します。
