# Install in proxmox

https://www.jwtechtips.top/how-to-install-openwrt-in-proxmox/

# Upgrade

```bash
OPENWRT_VERSION=22.03.0
wget https://downloads.openwrt.org/releases/${OPENWRT_VERSION}/targets/x86/64/openwrt-${OPENWRT_VERSION}-x86-64-generic-squashfs-combined.img.gz

sysupgrade -v ./openwrt-${OPENWRT_VERSION}-x86-64-generic-squashfs-combined.img.gz
```

```sh
opkg update

# Install ja package
opkg install luci-i18n-base-ja luci-i18n-firewall-ja luci-i18n-opkg-ja

# Install curl
opkg install curl

# Download & Install ipip6 package
curl -L -o ./ipip6_0.1_all.ipk "https://drive.google.com/uc?export=download&id=1iWwjliIeP-Bud2Bje8w-yHe7DE9oWdtn"
opkg install ./ipip6_0.1_all.ipk

# Install Wireguard
opkg install luci-i18n-wireguard-ja qrencode

# Install OpenVPN
opkg install luci-i18n-openvpn-ja openvpn-openssl kmod-ovpn-dco openssl-util

# Install DDNS
opkg install luci-i18n-ddns-ja ddns-scripts-cloudflare

# reboot
reboot
```