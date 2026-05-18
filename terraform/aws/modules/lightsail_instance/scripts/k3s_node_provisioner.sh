#!/bin/sh
# Lightsail user_data: k3s クラスタノードの最小初期化。
#   - GitHub 公開鍵で SSH authorized_keys を上書き
#   - blueprint デフォルトの TrustedUserCAKeys (SSM 用) を無効化
#   - cloudflared / tailscale をパッケージインストール (認証情報は後段で投入)
# k3s 本体 / kernel modules / sysctl / hostname は ansible 側で設定する。
#
# Lightsail の user_data は cloud-init 経由で /bin/sh (Ubuntu では dash) として
# 実行される (shebang `#!/bin/bash` を書いても sh 経由で呼ばれる事例あり)。
# したがって本スクリプトは POSIX shell 互換で書く: 配列 / `function` キーワード /
# ハイフン入り関数名などの bash 拡張構文は使わない。

set -ex

# cloud-init と apt の競合を避けるためロック解放を待つラッパー
wait_apt() {
    for lock_file in \
        /var/lib/apt/lists/lock \
        /var/lib/dpkg/lock \
        /var/lib/dpkg/lock-frontend
    do
        if [ -f "$lock_file" ]; then
            while fuser "$lock_file" >/dev/null 2>&1; do
                sleep 5
            done
        fi
    done

    apt-get "$@"
}

curl -fsSL https://github.com/AkashiSN.keys > /home/ubuntu/.ssh/authorized_keys
curl -fsSL https://sshid.io/akashisn >> /home/ubuntu/.ssh/authorized_keys
sed -i 's/^TrustedUserCAKeys/# TrustedUserCAKeys/g' /etc/ssh/sshd_config
service ssh restart

export DEBIAN_FRONTEND=noninteractive
wait_apt update
wait_apt upgrade -y

# cloudflared (auth は `cloudflared service install <TOKEN>` を後段で実行)
mkdir -p --mode=0755 /usr/share/keyrings
curl -fsSL --retry 10 https://pkg.cloudflare.com/cloudflare-main.gpg | tee /usr/share/keyrings/cloudflare-main.gpg >/dev/null
echo 'deb [signed-by=/usr/share/keyrings/cloudflare-main.gpg] https://pkg.cloudflare.com/cloudflared any main' | tee /etc/apt/sources.list.d/cloudflared.list
wait_apt update
wait_apt install -y cloudflared

# tailscale (auth は `tailscale up --authkey=...` を後段で実行)
curl -fsSL https://tailscale.com/install.sh | sh
