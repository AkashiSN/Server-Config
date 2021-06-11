#!/bin/bash
set -eu

cat << PASSWORD | passwd samba
$SAMBA_PASSWORD
$SAMBA_PASSWORD
PASSWORD

cat << PASSWORD | smbpasswd -a -s samba
$SAMBA_PASSWORD
$SAMBA_PASSWORD
PASSWORD

mkdir -p /var/promtail/samba

cat << EOS > /etc/samba/smb.conf
[global]
  workgroup = WORKGROUP
  netbios name = NAS-SERVER
  server string = nas server (Samba, Ubuntu)

  log file = /var/promtail/samba/%m
  log level = 1
  max log size = 1000

  server role = standalone server

  usershare allow guests = no
  printcap name = /dev/null
  map to guest = Bad User

[nas]
  path = ${SAMBA_PATH}
  guest ok = no
  read only = no
  case sensitive = yes
  preserve case = yes
  short preserve case = no
EOS

/usr/sbin/smbd -F -S --no-process-group