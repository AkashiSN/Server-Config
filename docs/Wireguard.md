
## Install

```bash
# Install wireguard
sudo apt install -y wireguard
```

## Setup

```bash
# Set WIREGUARD_DIR env.
export WIREGUARD_DIR=/etc/wireguard

# Generate private key
wg genkey | sudo tee ${WIREGUARD_DIR}/server.key

# Generate public key
sudo cat ${WIREGUARD_DIR}/clients/server.key | wg pubkey | sudo tee ${WIREGUARD_DIR}/server.pub

# Generate preshared key
wg genpsk | sudo tee ${WIREGUARD_DIR}/preshared.key

# Change permission
sudo chmod 600 ${WIREGUARD_DIR}/server.key ${WIREGUARD_DIR}/server.pub ${WIREGUARD_DIR}/preshared.key
```

## Server config

```bash
# Set WIREGUARD_IP env.
export WIREGUARD_IP=10.254.0.1/24

# Create wireguard interface config.
cat << EOS | sudo tee ${WIREGUARD_DIR}/wg0.conf
[Interface]
PrivateKey = $(cat ${WIREGUARD_DIR}/server.key)
Address = ${WIREGUARD_IP}
ListenPort = 443
PostUp = iptables -A FORWARD -i wg0 -j ACCEPT; iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE; iptables -A FORWARD -i eth0 -j ACCEPT; iptables -t nat -A POSTROUTING -o wg0 -j MASQUERADE
PostDown = iptables -D FORWARD -i wg0 -j ACCEPT; iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE; iptables -D FORWARD -i eth0 -j ACCEPT; iptables -t nat -D POSTROUTING -o wg0 -j MASQUERADE

EOS
```

## Client config

```bash
cat ${WIREGUARD_DIR}/wireguard.sh
```

```bash
#!/bin/bash
set -eu

mkdir -p ${WIREGUARD_DIR}/clients

for CLIENT in "${CLIENTS[@]}"; do
	wg genkey | tee ${WIREGUARD_DIR}/clients/${CLIENT}-private.key
	cat ${WIREGUARD_DIR}/clients/${CLIENT}-private.key | wg pubkey | tee ${WIREGUARD_DIR}/clients/${CLIENT}-public.key
	chmod 600 ${WIREGUARD_DIR}/clients/${CLIENT}-private.key ${WIREGUARD_DIR}/clients/${CLIENT}-public.key

	cat << EOS > ${WIREGUARD_DIR}/clients/${CLIENT}.conf
[Interface]
PrivateKey = $(cat ${WIREGUARD_DIR}/clients/${CLIENT}-private.key)
Address = ${CLIENT_START_IP}/32

[Peer]
PublicKey = $(cat ${WIREGUARD_DIR}/server.pub)
PresharedKey = $(cat ${WIREGUARD_DIR}/preshared.key)
Endpoint = ${ENDPOINT}
AllowedIPs = 0.0.0.0/0
EOS

	cat << EOS >> ${WIREGUARD_DIR}/wg0.conf
[Peer]
# ${CLIENT}
PublicKey = $(cat ${WIREGUARD_DIR}/clients/${CLIENT}-public.key)
PresharedKey = $(cat ${WIREGUARD_DIR}/preshared.key)
AllowedIPs = ${CLIENT_START_IP}/32
PersistentKeepalive = 25

EOS

	CLIENT_START_IP=$(echo $CLIENT_START_IP | awk -F "." '{print $1"."$2"."$3"."$4+1}')
done
```

```bash
# Set env.
export CLIENT_START_IP=10.254.2.2
export ENDPOINT=host:443
export CLIENTS=("MacBookPro13" "Pixel3XL" "iPadPro11" "iPhone7" "Nexus5X")

# Run script.
sudo /bin/bash ${WIREGUARD_DIR}/wireguard.sh
```

## Start, Stop

```bash
# Start wireguard.
sudo wg-quick up wg0

# Stop wireguard.
sudo wg-quick down wg0
```