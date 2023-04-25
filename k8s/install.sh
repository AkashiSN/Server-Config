#!/bin/bash
set -eu

# time
timedatectl set-timezone Asia/Tokyo
sed -i 's/#NTP=/NTP=ntp.nict.jp/g' /etc/systemd/timesyncd.conf
timedatectl set-ntp true
systemctl restart systemd-timesyncd.service

# disable swap
swapoff -a
sed -i '/swap/s/^/# /g' /etc/fstab

# logrotate
sed -i 's/weekly/daily/g' /etc/logrotate.conf
sed -i 's/weeks/days/g' /etc/logrotate.conf
sed -i 's/#dateext/dateext/g' /etc/logrotate.conf
sed -i 's/#compress/compress/g' /etc/logrotate.conf

cat <<EOF > /etc/logrotate.d/rsyslog
/var/log/syslog
/var/log/mail.info
/var/log/mail.warn
/var/log/mail.err
/var/log/mail.log
/var/log/daemon.log
/var/log/kern.log
/var/log/auth.log
/var/log/user.log
/var/log/lpr.log
/var/log/cron.log
/var/log/debug
/var/log/messages
{
	rotate 4
	daily
  dateext
  dateformat _%Y-%m-%d
	missingok
	notifempty
	compress
	sharedscripts
	postrotate
		/usr/lib/rsyslog/rsyslog-rotate
	endscript
}
EOF

service logrotate restart

# kernel module
cat <<EOF > /etc/modules-load.d/crio.conf
overlay
br_netfilter
EOF

# kernel parameter
cat <<EOF > /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables  = 1
net.ipv4.conf.all.forwarding        = 1
net.ipv6.conf.all.forwarding        = 1

vm.max_map_count = 262144
EOF

# install legacy version
apt-get install -y iptables arptables ebtables

# switch legacy version
update-alternatives --set iptables /usr/sbin/iptables-legacy
update-alternatives --set ip6tables /usr/sbin/ip6tables-legacy
update-alternatives --set arptables /usr/sbin/arptables-legacy
update-alternatives --set ebtables /usr/sbin/ebtables-legacy

# Install dependency
apt-get install -y apt-transport-https ca-certificates curl

# Add kubernetes apt repo
curl -fsSLo /usr/share/keyrings/kubernetes-archive-keyring.gpg https://packages.cloud.google.com/apt/doc/apt-key.gpg
echo "deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" | tee /etc/apt/sources.list.d/kubernetes.list

apt-get update

# Install CRI-O
export OS="xUbuntu_22.04"
export K8S_MAJOR_VERSION="1.26"

echo "deb [signed-by=/usr/share/keyrings/libcontainers-archive-keyring.gpg] https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/${OS}/ /" > /etc/apt/sources.list.d/devel:kubic:libcontainers:stable.list
echo "deb [signed-by=/usr/share/keyrings/libcontainers-crio-archive-keyring.gpg] https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable:/cri-o:/${K8S_MAJOR_VERSION}/${OS}/ /" > /etc/apt/sources.list.d/devel:kubic:libcontainers:stable:cri-o:${K8S_MAJOR_VERSION}.list

mkdir -p /usr/share/keyrings
curl -L https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/${OS}/Release.key | gpg --dearmor -o /usr/share/keyrings/libcontainers-archive-keyring.gpg
curl -L https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable:/cri-o:/${K8S_MAJOR_VERSION}/${OS}/Release.key | gpg --dearmor -o /usr/share/keyrings/libcontainers-crio-archive-keyring.gpg

apt-get update
apt-get install -y cri-o cri-o-runc

systemctl daemon-reload
systemctl enable crio
systemctl start crio

# chane ulimit
sed -ie 'N;s!# default_ulimits = \[!default_ulimits = \[\n"nofile=65536:65536",\n"memlock=-1:-1"\n\]!g' /etc/crio/crio.conf

# Install kubelet kubeadm kubectl
export K8S_APT_VERSION="$(apt-cache show kubelet | grep Version | grep ${K8S_MAJOR_VERSION} | head -n 1 | cut -d ' ' -f 2)"

apt-get install -y "kubelet=${K8S_APT_VERSION}" "kubeadm=${K8S_APT_VERSION}" "kubectl=${K8S_APT_VERSION}"

apt-mark hold kubelet kubeadm kubectl

# network
export INTERFACE="$(ip route show default | sed -nE -e 's/.*dev (\w+).*/\1/p')"
export NODE_IP="$(ip addr show dev ${INTERFACE} | sed -nE -e 's/.+inet ([0-9.]+).+/\1/p')"
echo "KUBELET_EXTRA_ARGS=\"--node-ip=${NODE_IP}\"" | tee /etc/default/kubelet

systemctl daemon-reload
systemctl restart kubelet

# change cgroups settings
sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT=""/GRUB_CMDLINE_LINUX_DEFAULT="systemd.unified_cgroup_hierarchy=false"/g' /etc/default/grub
update-grub

# Install iscsi-initiator
apt-get install -y open-iscsi

# Install helm
curl https://baltocdn.com/helm/signing.asc | gpg --dearmor | tee /usr/share/keyrings/helm.gpg > /dev/null

echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/helm.gpg] https://baltocdn.com/helm/stable/debian/ all main" | tee /etc/apt/sources.list.d/helm-stable-debian.list

apt-get update
apt-get install -y helm

# Install jq
apt-get install -y jq

# Disable DNS stub resolve
sed -i -e "s/.*DNSStubListener=yes/DNSStubListener=no/" /etc/systemd/resolved.conf
cd /etc
ln -sf ../run/systemd/resolve/resolv.conf resolv.conf
systemctl restart systemd-resolved.service
cd

# upgrade
apt-get update
apt-get upgrade -y
