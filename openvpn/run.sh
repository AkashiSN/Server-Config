#!/bin/sh

# arg 1: tcp or udp

# ERROR: Cannot open TUN/TAP dev /dev/net/tun: No such file or directory (errno=2)が出ないようにするため
mkdir -p /dev/net
if [ ! -c /dev/net/tun ]; then
    mknod /dev/net/tun c 10 200
fi

# `ip addr`コマンドの結果からネットワークデバイス名を抽出する
OVPN_NATDEVICE=$(ip addr | awk 'match($0, /global [[:alnum:]]+/) {print substr($0, RSTART+7, RLENGTH)}')
if [ -z "${OVPN_NATDEVICE}" ]; then
    ip addr
    echo "Failed to extract OVPN_NATDEVICE."
    exit 1
fi

# iptablesの設定
iptables -t nat -C POSTROUTING -s 192.168.255.0/24 -o ${OVPN_NATDEVICE} -j MASQUERADE 2>/dev/null || {
    iptables -t nat -A POSTROUTING -s 192.168.255.0/24 -o ${OVPN_NATDEVICE} -j MASQUERADE
}

# OpenVPNサーバの起動
/usr/sbin/openvpn \
    --config "/opt/openvpn/openvpn.conf" \
    --client-config-dir "/opt/openvpn/config" \
    --proto "$1" \
    --status "openvpn-status_$1.log"
