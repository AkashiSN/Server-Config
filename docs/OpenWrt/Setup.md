# Install in proxmox

https://www.jwtechtips.top/how-to-install-openwrt-in-proxmox/

# Upgrade

```bash
OPENWRT_VERSION=22.03.5
wget -O openwrt.img.gz https://downloads.openwrt.org/releases/${OPENWRT_VERSION}/targets/x86/64/openwrt-${OPENWRT_VERSION}-x86-64-generic-ext4-combined.img.gz
wget -O openwrt.img.gz https://downloads.openwrt.org/releases/${OPENWRT_VERSION}/targets/bcm27xx/bcm2711/openwrt-${OPENWRT_VERSION}-bcm27xx-bcm2711-rpi-4-ext4-sysupgrade.img.gz
wget -O openwrt.img.gz https://downloads.openwrt.org/releases/${OPENWRT_VERSION}/targets/rockchip/armv8/openwrt-${OPENWRT_VERSION}-rockchip-armv8-friendlyarm_nanopi-r4s-ext4-sysupgrade.img.gz

sysupgrade -v ./openwrt.img.gz
```

```sh
opkg update

# Install ja package
opkg install luci-i18n-base-ja luci-i18n-firewall-ja luci-i18n-opkg-ja luci-i18n-uhttpd-ja

# Install curl
opkg install curl

# Install cloudflared
curl -L --output /tmp/cloudflared https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm64
chmod +x /tmp/cloudflared
mv /tmp/cloudflared /usr/bin/cloudflared

export TOKEN=""
cat <<EOF > /etc/init.d/cloudflared
#!/bin/sh /etc/rc.common

cmd="/usr/bin/cloudflared --pidfile /var/run/cloudflared.pid --autoupdate-freq 24h0m0s tunnel run --token $TOKEN"
pid_file="/var/run/cloudflared.pid"

# Timeout (in seconds) to wait for DNS
DNS_TIMEOUT=60

# Function to check if DNS is ready
dns_ready() {
    nslookup example.com > /dev/null 2>&1
    return \$?
}

# Function to wait for DNS
wait_for_dns() {
    local retries=0
    until dns_ready || [ \$retries -ge \$DNS_TIMEOUT ]
    do
        sleep 1
        retries=\$((retries + 1))
    done
}

START=99
STOP=01

start() {
    wait_for_dns
    if dns_ready; then
        echo "Starting cloudflared"
        (\$cmd 2>&1 | logger -t cloudflared) &
    else
        echo "DNS not ready. Timeout reached."
        exit 1
    fi
}

stop() {
    if [ -f "\$pid_file" ]; then
        pid=\$(cat "\$pid_file")
        echo "Stopping cloudflared with PID \$pid"
        kill "\$pid"
        rm -f "\$pid_file"
    else
        echo "PID file not found. Cannot stop cloudflared."
    fi
}
EOF

chmod +x /etc/init.d/cloudflared
/etc/init.d/cloudflared enable
echo "/etc/init.d/cloudflared" >> /etc/sysupgrade.conf

# Install OpenSSH sftp
opkg install openssh-sftp-server

# Download & Install ipip6 package
curl -L -o ./ipip6_0.1_all.ipk "https://drive.google.com/uc?export=download&id=1iWwjliIeP-Bud2Bje8w-yHe7DE9oWdtn"
opkg install ./ipip6_0.1_all.ipk

# Install Wireguard
opkg install luci-i18n-wireguard-ja qrencode

# Install OpenVPN
opkg install luci-i18n-openvpn-ja openvpn-openssl kmod-ovpn-dco openssl-util

# Install SoftEther-VPN
opkg install softethervpn5-server luci-app-softether

# Install usb-net
opkg install kmod-usb-net-rndis kmod-usb-net-cdc-ncm

# Install usb-lan-driver
opkg install kmod-usb-net-asix-ax88179

# Install DDNS
opkg install luci-i18n-ddns-ja ddns-scripts-cloudflare

# Install Wake on Lan
opkg install luci-i18n-wol-ja

# Install ACME
opkg install luci-i18n-acme-ja acme-dnsapi

# Install Quemu Guest Agent
opkg install qemu-ga

# Install BGP & OSPF
opkg install quagga quagga-zebra quagga-bgpd quagga-ospfd quagga-watchquagga quagga-vtysh

# Install mwan3
opkg install luci-app-mwan3 luci-i18n-mwan3-ja

# Install Bird
opkg install bird2 bird2c bird2cl

# reboot
reboot
```


sample bgp conf
```conf
router bgp 65000
 bgp router-id 10.10.0.1
 neighbor 10.10.0.10 remote-as 65000
 neighbor 10.10.0.10 interface wg1
 neighbor 10.10.0.10 route-reflector-client
 neighbor 10.10.0.10 soft-reconfiguration inbound
 neighbor 10.10.0.100 remote-as 65000
 neighbor 10.10.0.100 interface wg1
 neighbor 10.10.0.100 route-reflector-client
 neighbor 10.10.0.100 soft-reconfiguration inbound
```

bird conf
```
cat /etc/bird.conf
log syslog all;
router id 172.16.254.100;

protocol device {
    scan time 10;
}

protocol direct direct1 {
    ipv6;
    interface "eth1";
}

protocol kernel {
    scan time 10;
    ipv6 {
        import all;
        export filter {
            if proto = "direct1" then reject;
            accept;
        };
    };
}

template bgp tor {
    local IPv6_PREFIX::254:1 as 65000;
    rr client;
    direct;
    interface "eth1";

    ipv6 {
        import all;
        export none;
    };
}

protocol bgp k8s_control_plane from tor {
    neighbor IPv6_PREFIX::254:50 as 65000;
}

protocol bgp worker_node from tor {
    neighbor IPv6_PREFIX::254:105 as 65000;
}

```