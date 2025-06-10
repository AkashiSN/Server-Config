#!/bin/bash
set -ex

# Set DEBIAN_FRONTEND
export DEBIAN_FRONTEND=noninteractive

# Download ssh pubkey
curl https://raw.githubusercontent.com/AkashiSN/dotfiles/refs/heads/main/ssh/gpg.pub | tee /home/ubuntu/.ssh/authorized_keys

# Install wireguard
apt-get update
apt-get upgrade -y
apt-get install -y wireguard

# Server
# Generate private key
wg genkey | tee /etc/wireguard/private.key
# Change permission
chmod go= /etc/wireguard/private.key
# Generate public key
cat /etc/wireguard/private.key | wg pubkey | tee /etc/wireguard/public.key

# Set env
export WIREGUARD_SERVER_IP=10.254.0.1
export WIREGUARD_CLIENT_IP=10.254.0.2
export WIREGUARD_SERVER_DEFAULT_IF=$(ip route show default | sed -nE -e 's/.*dev (\w+).*/\1/p')
export WIREGUARD_SERVER_GLOBAL_IP=$(dig -4 @1.1.1.1 whoami.cloudflare TXT CH +short | sed 's/"//g')
export WIREGUARD_SERVER_DEFAULT_IPv6_IF=$(ip -6 route show default | sed -nE -e 's/.*dev (\w+).*/\1/p')
export WIREGUARD_SERVER_IPv6_PREFIX=$(ip -6 route show dev ${WIREGUARD_SERVER_DEFAULT_IPv6_IF} | sed -nE -e 's/(^[^(fe80)][0-9a-f:]+)::.+/\1/p')
export WIREGUARD_SERVER_IPv6=$(ip -6 addr show dev ${WIREGUARD_SERVER_DEFAULT_IPv6_IF} | sed -nE -e 's/.+inet6 ([0-9a-f:]+).+/\1/p' | grep ${WIREGUARD_SERVER_IPv6_PREFIX})

# Generate server config
cat > /etc/wireguard/wg0.conf << EOF
[Interface]
PrivateKey = $(cat /etc/wireguard/private.key)
Address = ${WIREGUARD_SERVER_IP}/24
ListenPort = 51820

PostUp = iptables -A FORWARD -i %i -j ACCEPT
PostUp = iptables -A FORWARD -o %i -j ACCEPT
PostUp = iptables -t nat -A POSTROUTING -o ${WIREGUARD_SERVER_DEFAULT_IF} -j MASQUERADE
PostUp = iptables -t nat -A PREROUTING -i ${WIREGUARD_SERVER_DEFAULT_IF} -j DNAT --to-destination ${WIREGUARD_CLIENT_IP}

PostDown = iptables -D FORWARD -i %i -j ACCEPT
PostDown = iptables -D FORWARD -o %i -j ACCEPT
PostDown = iptables -t nat -D POSTROUTING -o ${WIREGUARD_SERVER_DEFAULT_IF} -j MASQUERADE
PostDown = iptables -t nat -D PREROUTING -i ${WIREGUARD_SERVER_DEFAULT_IF} -j DNAT --to-destination ${WIREGUARD_CLIENT_IP}

EOF

# Setting ipv4 forward
echo "net.ipv4.ip_forward=1" | tee -a /etc/sysctl.conf
sysctl -p

# Enable and start wireguard
systemctl enable wg-quick@wg0
systemctl start wg-quick@wg0
