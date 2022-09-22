#!/bin/bash
set -eu

# Install ndppd
sudo apt install -y ndppd

# Create ndppd unit file
cat <<EOF | sudo tee /etc/systemd/system/ndppd.service
[Unit]
Description=NDP Proxy Daemon
Wants=network-online.target
After=network-online.target

[Service]
ExecStart=/usr/sbin/ndppd -d -p /run/ndppd.pid
Type=forking
PIDFile=/run/ndppd.pid

[Install]
WantedBy=multi-user.target
EOF

DEFAULT_INTERFACE="$(ip route | grep -oP 'default .* dev \K[^ ]+')"
IPV6_ADDRESS="$(ip -6 addr show dev "${DEFAULT_INTERFACE}" | grep global | grep -oP 'inet6 \K[^ ]+')"
IPV6_PREFIX="$(echo "${IPV6_ADDRESS}" | grep -oP '.+?:.+?:.+?:.+?:')"
IPV4_ADDRESS_SUFIX="$(ip addr show dev "${DEFAULT_INTERFACE}" | grep -oP 'inet \K[^ ]+' | grep -oP '[0-9]+.[0-9]+.\K[0-9]+')"
DOCKER_IPV6_SUBNET="${IPV6_PREFIX}$((${IPV4_ADDRESS_SUFIX}+1))"

DOCKER_NETWORK_INTERFACE="$(sudo docker network ls --format 'table {{.Name}} {{.ID}}' | grep -oP 'external \K.*')" || true
if [ -n "${DOCKER_NETWORK_INTERFACE}" ]; then
  if [[ ! "$(sudo docker network inspect ${DOCKER_NETWORK_INTERFACE} | jq '.[0].IPAM.Config[1].Subnet')" =~ "${DOCKER_IPV6_SUBNET}" ]]; then
    sudo docker network rm "${DOCKER_NETWORK_INTERFACE}"
    DOCKER_NETWORK_INTERFACE=""
  fi
fi

if [ -z "${DOCKER_NETWORK_INTERFACE}" ]; then
  sudo docker network create --driver bridge --ipam-driver default --ipv6 --subnet "${DOCKER_IPV6_SUBNET}::/80" --gateway "${DOCKER_IPV6_SUBNET}::1" external
fi

cat <<EOF | sudo tee /etc/ndppd.conf
proxy ${DEFAULT_INTERFACE} {
    rule ${DOCKER_IPV6_SUBNET}::/80 {
        static
    }
}
EOF

sudo systemctl daemon-reload
sudo systemctl enable ndppd.service
sudo systemctl restart ndppd.service