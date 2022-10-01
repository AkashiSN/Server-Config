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

# Install dependency
apt-get install -y apt-transport-https ca-certificates curl

# Add kubernetes apt repo
curl -fsSLo /usr/share/keyrings/kubernetes-archive-keyring.gpg https://packages.cloud.google.com/apt/doc/apt-key.gpg
echo "deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" | tee /etc/apt/sources.list.d/kubernetes.list

apt-get update

# Install CRI-O
export OS="xUbuntu_22.04"
export K8S_MAJOR_VERSION="1.24"

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

# Install kubelet kubeadm kubectl
export K8S_APT_VERSION="$(apt-cache show kubelet | grep Version | grep ${K8S_MAJOR_VERSION} | head -n 1 | cut -d ' ' -f 2)"

apt-get install -y "kubelet=${K8S_APT_VERSION}" "kubeadm=${K8S_APT_VERSION}" "kubectl=${K8S_APT_VERSION}"

apt-mark hold kubelet kubeadm kubectl

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

# reboot
reboot
```

Only master-node
```bash
# k8s init
sudo kubeadm init --pod-network-cidr=192.168.0.0/16

mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

kubectl get nodes
```

```bash
# Calico
helm repo add projectcalico https://projectcalico.docs.tigera.io/charts
helm repo update

export CALICO_VERSION="v3.24.1"
helm install calico projectcalico/tigera-operator --version ${CALICO_VERSION} --namespace tigera-operator --create-namespace

watch kubectl get pods -n calico-system

# metallb
helm repo add metallb https://metallb.github.io/metallb
helm repo update

export METALLB_VERSION="0.13.5"
helm install metallb metallb/metallb --version ${METALLB_VERSION} --namespace metallb-system --create-namespace

watch kubectl get pod -n metallb-system

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
helm repo add nginx-stable https://helm.nginx.com/stable
helm repo update

export NGINX_INGRESS_VERSION="0.14.1"
helm install nginx-ingress nginx-stable/nginx-ingress --version ${NGINX_INGRESS_VERSION} --namespace ingress-nginx --create-namespace

watch kubectl get pod -n ingress-nginx

# stackgres
helm repo add stackgres-charts https://stackgres.io/downloads/stackgres-k8s/stackgres/helm/
helm repo update

helm install --namespace stackgres stackgres-operator \
    --set-string adminui.service.type=LoadBalancer \
    --set-string adminui.service.loadBalancerIP="172.16.254.20" \
stackgres-charts/stackgres-operator --create-namespace

watch kubectl get deployment -n stackgres

kubectl patch secrets --namespace stackgres stackgres-restapi --type json -p '[{"op":"remove","path":"/data/clearPassword"}]'
```

## Local manifests

```bash
kubectl apply -f sc.yml
```

### Minecraft
```bash
kubectl create namespace minecraft

kubectl create secret generic --namespace minecraft --from-file=./.secrets/minecraft_rcon_password minecraft-secrets
kubectl create secret generic --namespace minecraft --from-file=./.secrets/minecraft_whitelist minecraft-whitelist
kubectl apply -f minecraft.yml
```

### Nextcloud
```bash
kubectl create namespace nextcloud

```
