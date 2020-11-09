#!/bin/sh

# ERROR: Cannot open TUN/TAP dev /dev/net/tun: No such file or directory (errno=2)が出ないようにするため
mkdir -p /dev/net
if [ ! -c /dev/net/tun ]; then
    mknod /dev/net/tun c 10 200
fi

# クライアント用のネットワーク
OVPN_SERVER=${OVPN_SERVER:-172.16.10.0}

# サーバの属しているセグメント
SERVER_SEGMENT=${SERVER_SEGMENT:-"172.16.0.0 255.255.254.0"}

# サーバのデフォルトゲートウェイ
DEFAULT_GATEWAY=${DEFAULT_GATEWAY:-172.16.0.1}

# `ip addr`コマンドの結果からネットワークデバイス名を抽出する
OVPN_NATDEVICE=$(ip addr | awk 'match($0, /global [[:alnum:]]+/) {print substr($0, RSTART+7, RLENGTH)}')
if [ -z "${OVPN_NATDEVICE}" ]; then
    ip addr
    echo "Failed to extract OVPN_NATDEVICE."
    exit 1
fi

# iptablesの設定
iptables -t nat -A POSTROUTING -s ${OVPN_SERVER}/24 -o ${OVPN_NATDEVICE} -j MASQUERADE || {
    iptables -t nat -C POSTROUTING -s ${OVPN_SERVER}/24 -o ${OVPN_NATDEVICE} -j MASQUERADE
}

# OpenVPNサーバの起動
/usr/sbin/openvpn \
    --cd "/opt/openvpn" \
    \
    --port  "443" \
    --proto "tcp4" \
    --dev   "tun" \
    \
    --ca       "/opt/openvpn/cert/server/cacert.pem" \
    --cert     "/opt/openvpn/cert/server/server.pem" \
    --key      "/opt/openvpn/cert/server/server.key" \
    --dh       "/opt/openvpn/cert/server/dh.pem" \
    --tls-auth "/opt/openvpn/cert/server/ta.key" "0" \
    \
    --auth "SHA256" \
    --cipher "AES-256-GCM" \
    --data-ciphers "AES-256-GCM" \
    --tls-version-min "1.2" \
    --tls-cipher "TLS-ECDHE-ECDSA-WITH-AES-256-GCM-SHA384:TLS-ECDHE-RSA-WITH-AES-256-GCM-SHA384" \
    --reneg-sec "60" \
    \
    --topology subnet \
    --server "${OVPN_SERVER}" "255.255.255.0" \
    --ifconfig-pool-persist ipp.txt \
    --push "route ${SERVER_SEGMENT} 255.255.0.0" \
    --push "dhcp-option DNS ${DEFAULT_GATEWAY}" \
    \
    --keepalive 10 120 \
    --persist-key \
    --persist-tun \
    \
    --status openvpn-status.log \
    --verb 3 \
    \
    --tun-mtu 1500 \
    --mssfix 1460
