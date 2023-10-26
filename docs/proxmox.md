# Proxmox

## Redirect https 8006 to 443
```bash
# add the ip tables rule
/sbin/iptables -F
/sbin/iptables -t nat -F
/sbin/iptables -t nat -A PREROUTING -p tcp --dport 443 -j REDIRECT --to-port 8006
# install iptables-persistent
apt install iptables-persistent -y
```

## Pcie Passthrough
```bash
# https://wiki.archlinux.org/title/Intel_GVT-g
# https://pve.proxmox.com/wiki/PCI(e)_Passthrough
# enable intel gvt
# enable iommu, IOMMU Passthrough Mode
sed -i -e 's/$/ quiet i915.enable_gvt=1 i915.enable_guc=0 kvm.ignore_msrs=1 intel_iommu=on iommu=pt/' /etc/kernel/cmdline

proxmox-boot-tool refresh

cat >/etc/modules-load.d/kvm-gvt-g.conf << EOF
kvmgt
vfio_iommu_type1
vfio_mdev
EOF

cat >/etc/modules-load.d/pass-through.conf << EOF
vfio
vfio_iommu_type1
vfio_pci
vfio_virqfd
EOF

update-initramfs -u -k all
```

```bash
reboot
```

```bash
$ dmesg | grep -E "IOMMU|enabled"
DMAR: IOMMU enabled

$ lspci | grep VGA
00:02.0 VGA compatible controller: Intel Corporation CoffeeLake-S GT2 [UHD Graphics 630]
01:00.0 VGA compatible controller: NVIDIA Corporation GM204 [GeForce GTX 980] (rev a1)

$ GVT_PCI="0000:00:02.0"
$ ls /sys/bus/pci/devices/$GVT_PCI/mdev_supported_types/
i915-GVTg_V5_4  i915-GVTg_V5_8
```

## NTP

```bash
# https://pve.proxmox.com/wiki/Time_Synchronization
sed -i -e 's/2.debian.pool.ntp.org/ntp.nict.jp/' /etc/chrony/chrony.conf
systemctl restart chronyd
```

```bash
$ journalctl -f -u chrony
$ hwclock --systohc
$ hwclock --show
$ date
```

## ACME

```bash
export email=
export domain=
export cf_token=
export cf_zone_id=

cat >/tmp/dbs-cf-token << EOF
CF_Token=${cf_token}
CF_Zone_ID=${cf_zone_id}
EOF

pvenode acme account register default "${email}"
pvenode acme plugin add dns cloudflare --api cf --data /tmp/dbs-cf-token
pvenode config set --acme account=default --acmedomain0 domain=${domain},plugin=cloudflare
pvenode acme cert order

systemctl restart pveproxy

rm /tmp/dbs-cf-token
```

## Troubleshooting

### RRDC update error /var/lib/rrdcached/db/pve2-node/pve: -1

https://forum.proxmox.com/threads/rrdc-update-errors.81150/


```log
Oct 26 14:57:02 pve pmxcfs[1945]: [status] notice: RRDC update error /var/lib/rrdcached/db/pve2-node/pve: -1
Oct 26 14:57:02 pve pmxcfs[1945]: [status] notice: RRD update error /var/lib/rrdcached/db/pve2-node/pve: /var/lib/rrdcached/db/pve2-node/pve: illegal attempt to update using time 1698299822 when last update time is 1698324250 (minimum one second step)
Oct 26 14:57:02 pve pmxcfs[1945]: [status] notice: RRDC update error /var/lib/rrdcached/db/pve2-storage/pve/local: -1
Oct 26 14:57:02 pve pmxcfs[1945]: [status] notice: RRDC update error /var/lib/rrdcached/db/pve2-storage/pve/local-zfs: -1
Oct 26 14:57:02 pve pmxcfs[1945]: [status] notice: RRD update error /var/lib/rrdcached/db/pve2-storage/pve/local-zfs: /var/lib/rrdcached/db/pve2-storage/pve/local-zfs: illegal attempt to update using time 1698299822 when last update time is 1698324250 (minimum one second step)
```
```bash
rm -rf /var/lib/rrdcached/db
```