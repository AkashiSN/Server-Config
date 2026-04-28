#!/bin/bash
set -ex

function wait-apt () {
    # Wait for another apt
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

# Set ssh pubkey
curl -fsSL https://github.com/AkashiSN.keys > /home/ubuntu/.ssh/authorized_keys
sed -i 's/^TrustedUserCAKeys/# TrustedUserCAKeys/g' /etc/ssh/sshd_config
service ssh restart

# Set DEBIAN_FRONTEND
export DEBIAN_FRONTEND=noninteractive

# Set hostname
hostnamectl set-hostname k3s-lightsail
echo "127.0.1.1 k3s-lightsail" >> /etc/hosts

# Upgrade
wait-apt update
wait-apt upgrade -y

# Install cloudflared
# Add cloudflare gpg key
mkdir -p --mode=0755 /usr/share/keyrings
curl -fsSL --retry 10 https://pkg.cloudflare.com/cloudflare-main.gpg | tee /usr/share/keyrings/cloudflare-main.gpg >/dev/null

# Add this repo to your apt repositories
echo 'deb [signed-by=/usr/share/keyrings/cloudflare-main.gpg] https://pkg.cloudflare.com/cloudflared any main' | tee /etc/apt/sources.list.d/cloudflared.list

# install cloudflared
wait-apt update
wait-apt install -y cloudflared

# Install zfs
wait-apt install -y zfsutils-linux zfsnap

# Install tailscale
curl -fsSL https://tailscale.com/install.sh | sh

# Setting ipv4 forward/etc/sysctl.conf
sed -i -e '/^#net.ipv4.ip_forward/s/^#//g' /etc/sysctl.conf
sysctl -p
