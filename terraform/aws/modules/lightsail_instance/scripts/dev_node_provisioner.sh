#!/bin/bash
# Lightsail user_data: リモート SSH 開発用ノードの最小初期化。
#   - GitHub 公開鍵で SSH authorized_keys を上書き
#   - blueprint デフォルトの TrustedUserCAKeys (SSM 用) を無効化
#   - cloudflared / tailscale をパッケージインストール (認証情報は後段で投入)
#   - 開発用の基本パッケージ (git / make / build-essential / jq) をインストール

set -ex

# cloud-init と apt の競合を避けるためロック解放を待つラッパー
function wait-apt () {
    LOCK_FILES=(
        "/var/lib/apt/lists/lock"
        "/var/lib/dpkg/lock"
        "/var/lib/dpkg/lock-frontend"
    )
    for lock_file in "${LOCK_FILES[@]}"; do
        if [ -f "$lock_file" ]; then
            while fuser "$lock_file" >/dev/null 2>&1; do
                sleep 5
            done
        fi
    done

    apt-get $@
}

curl -fsSL https://github.com/AkashiSN.keys > /home/ubuntu/.ssh/authorized_keys
sed -i 's/^TrustedUserCAKeys/# TrustedUserCAKeys/g' /etc/ssh/sshd_config
service ssh restart

export DEBIAN_FRONTEND=noninteractive
wait-apt update
wait-apt upgrade -y

# 開発用パッケージ
wait-apt install -y git make build-essential jq

# cloudflared (auth は `cloudflared service install <TOKEN>` を後段で実行)
mkdir -p --mode=0755 /usr/share/keyrings
curl -fsSL --retry 10 https://pkg.cloudflare.com/cloudflare-main.gpg | tee /usr/share/keyrings/cloudflare-main.gpg >/dev/null
echo 'deb [signed-by=/usr/share/keyrings/cloudflare-main.gpg] https://pkg.cloudflare.com/cloudflared any main' | tee /etc/apt/sources.list.d/cloudflared.list
wait-apt update
wait-apt install -y cloudflared

# tailscale (auth は `tailscale up --authkey=...` を後段で実行)
curl -fsSL https://tailscale.com/install.sh | sh
