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

## Notes

- Kubernetes 上のアプリ (dns / nextcloud / immich など) は [`../kubernetes/`](../kubernetes/README.md) 側で管理します。
