# Setup
## Environment
- Ubuntu 22.04

## Install k8s
```bash
# become root
sudo su

# disable swap
swapoff -a
sed -i '/swap/s/^/# /g' /etc/fstab

# kernel module
cat <<EOF > /etc/modules-load.d/crio.conf
overlay
br_netfilter
EOF

# kernel parameter
cat <<EOF > /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables  = 1
net.ipv4.ip_forward                 = 1
EOF

# install legacy version
apt-get install -y iptables arptables ebtables

# switch legacy version
update-alternatives --set iptables /usr/sbin/iptables-legacy
update-alternatives --set ip6tables /usr/sbin/ip6tables-legacy
update-alternatives --set arptables /usr/sbin/arptables-legacy
update-alternatives --set ebtables /usr/sbin/ebtables-legacy

# Install CRI-O
export OS="xUbuntu_22.04"
export K8S_MAJOR_VERSION="1.25"

echo "deb [signed-by=/usr/share/keyrings/libcontainers-archive-keyring.gpg] https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/${OS}/ /" > /etc/apt/sources.list.d/devel:kubic:libcontainers:stable.list
echo "deb [signed-by=/usr/share/keyrings/libcontainers-crio-archive-keyring.gpg] https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable:/cri-o:/${K8S_MAJOR_VERSION}/${OS}/ /" > /etc/apt/sources.list.d/devel:kubic:libcontainers:stable:cri-o:${K8S_MAJOR_VERSION}.list

mkdir -p /usr/share/keyrings
curl -L https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/${OS}/Release.key | gpg --dearmor -o /usr/share/keyrings/libcontainers-archive-keyring.gpg
curl -L https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable:/cri-o:/${K8S_MAJOR_VERSION}/${OS}/Release.key | gpg --dearmor -o /usr/share/keyrings/libcontainers-crio-archive-keyring.gpg

apt-get update
apt-get install -y cri-o cri-o-runc

systemctl daemon-reload
# CRI-O を永続化する
systemctl enable crio
# CRI-O を起動
systemctl start crio

# Install kubelet kubeadm kubectl
apt-get update
apt-get install -y apt-transport-https ca-certificates curl

curl -fsSLo /usr/share/keyrings/kubernetes-archive-keyring.gpg https://packages.cloud.google.com/apt/doc/apt-key.gpg
echo "deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" | tee /etc/apt/sources.list.d/kubernetes.list

apt-get update
export K8S_VERSION="$(apt-cache show kubelet | grep Version | grep ${K8S_MAJOR_VERSION} | head -n 1 | cut -d ' ' -f 2)"
apt-get install -y "kubelet=${K8S_VERSION}" "kubeadm=${K8S_VERSION}" "kubectl=${K8S_VERSION}"
apt-mark hold kubelet kubeadm kubectl

# change cgroups settings
sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT=""/GRUB_CMDLINE_LINUX_DEFAULT="systemd.unified_cgroup_hierarchy=false"/g' /etc/default/grub
update-grub

# reboot
reboot

# k8s init
sudo kubeadm init --pod-network-cidr=10.254.0.0/16

mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

# Calico
kubectl create -f https://docs.projectcalico.org/manifests/tigera-operator.yaml
kubectl create -f https://docs.projectcalico.org/manifests/custom-resources.yaml

# metallb
kubectl get configmap kube-proxy -n kube-system -o yaml | sed -e 's/mode: ""/mode: "ipvs"/' | kubectl diff -f - -n kube-system
kubectl get configmap kube-proxy -n kube-system -o yaml | sed -e "s/strictARP: false/strictARP: true/" | kubectl diff -f - -n kube-system

export METALLB_VERSION="v0.13.5"
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/${METALLB_VERSION}/config/manifests/metallb-native.yaml

kubectl apply -f - <<EOF
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: ippool
  namespace: metallb-system
spec:
  addresses:
  - 172.16.254.20-172.16.254.50
EOF

kubectl apply -f - <<EOF
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: l2adv
  namespace: metallb-system
EOF

# nginx-ingress
export NGINX_INGRESS_VERSION="v1.3.1"
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-${NGINX_INGRESS_VERSION}/deploy/static/provider/baremetal/deploy.yaml
```

## Local manifests

```bash
kubectl apply -f sc-lv.yml
```

```bash
kubectl create namespace mc
kubectl create secret generic --namespace mc --from-file=./.secrets/mc_rcon_password mc-secret
kubectl create secret generic --namespace mc --from-file=./.secrets/mc_whitelist mc-whitelist
kubectl apply -f mc.yml
```