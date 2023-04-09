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