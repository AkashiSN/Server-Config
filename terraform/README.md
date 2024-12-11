# infra

## Add snippets feature
```bash
pvesm set local --content vztmpl,snippets,iso,backup
```

## Create template vm

```bash
make template
make update-template
```

## Create proxmox user for terraform

```bash
pveum role add Terraform -privs "Datastore.Allocate Datastore.AllocateSpace Datastore.AllocateTemplate Datastore.Audit Pool.Allocate Sys.Audit Sys.Console Sys.Modify SDN.Use VM.Allocate VM.Audit VM.Clone VM.Config.CDROM VM.Config.Cloudinit VM.Config.CPU VM.Config.Disk VM.Config.HWType VM.Config.Memory VM.Config.Network VM.Config.Options VM.Migrate VM.Monitor VM.PowerMgmt User.Modify"

pveum user add terraform@pve

pveum aclmod / -user terraform@pve -role Terraform

pvesh create /access/users/terraform@pve/token/terraform --privsep 0
```
## Create VM

```bash
cd k3s or k8s
make vm
```

# for Hyper-V (Windows 11 Pro)

In wsl2
```bash
export hostname="k3s-hyperv"
export user_name=
export hashed_password=  # mkpasswd --method=yescrypt (via whois)
export github_id="AkashiSN"

cat >user-data <<EOF
#cloud-config
hostname: ${hostname}
manage_etc_hosts: true

users:
  - name: ${user_name}
    passwd: ${hashed_password}
    lock_passwd: false
    groups: adm, sudo
    home: /home/${user_name}
    shell: /bin/bash
    sudo: ALL=(ALL) NOPASSWD:ALL
    ssh_import_id:
      - gh:${github_id}

apt:
  conf: |
    APT {
      Periodic {
        Update-Package-Lists "0";
        Unattended-Upgrade "0";
      };
    };
  primary:
    - arches: [default]
      uri: http://ftp.udx.icscoe.jp/Linux/ubuntu
  security:
    - arches: [default]
      uri: http://security.ubuntu.com/ubuntu

package_update: true
package_upgrade: true

keyboard:
  layout: jp
  model: jp106

runcmd:
  - [ sh, -c, sed -i 's/^GRUB_CMDLINE_LINUX_DEFAULT=".*"/GRUB_CMDLINE_LINUX_DEFAULT="console=tty1"/' /etc/default/grub.d/50-cloudimg-settings.cfg ]
  - [ sh, -c, update-grub ]
EOF

export ipv4_address="172.16.254.40/24"
export ipv4_default_gateway="172.16.254.1"

cat >network-config <<EOF
#cloud-config
version: 2
ethernets:
  eth0:
    dhcp4: false
    dhcp6: false
    accept-ra: false
    link-local: [ ]
    addresses:
      - ${ipv4_address}
    routes:
      - to: default
        via: ${ipv4_default_gateway}
    nameservers:
      addresses:
        - 1.1.1.1
        - 8.8.8.8
EOF

sudo apt install qemu-utils cloud-image-utils

cloud-localds cloud-init.iso user-data -N network-config
mv cloud-init.iso /mnt/c/ProgramData/Microsoft/Windows/Virtual\ Hard\ Disks/cloud-init.iso

wget https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img
qemu-img convert -p -f qcow2 jammy-server-cloudimg-amd64.img -O vhdx -o subformat=dynamic jammy-server-cloudimg-amd64.vhdx
mv jammy-server-cloudimg-amd64.vhdx /mnt/c/ProgramData/Microsoft/Windows/Virtual\ Hard\ Disks/jammy-server-cloudimg-amd64.vhdx
```

In windows powershell
```powershell
$vmName = "k3s"
$vhdx = "C:\ProgramData\Microsoft\Windows\Virtual Hard Disks\jammy-server-cloudimg-amd64.vhdx"
$cloudInitIso = "C:\ProgramData\Microsoft\Windows\Virtual Hard Disks\cloud-init.iso"
$vmPath = "C:\ProgramData\Microsoft\Windows\Hyper-V\"
Resize-VHD -Path $vhdx -SizeBytes 64GB
New-VM $vmName -MemoryStartupBytes 16384mb -VHDPath $vhdx -Generation 1 -SwitchName Bridge -Path $vmPath
Set-VM -Name $vmName -ProcessorCount 8
Set-VM -Name $vmName -AutomaticCheckpointsEnabled $false
Set-VMMemory -VMName $vmName -DynamicMemoryEnabled $false
Set-VMDvdDrive -VMName $vmName -Path $cloudInitIso
Start-VM $vmName
```

wait for 1min
