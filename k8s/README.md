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
export CALICO_VERSION="v3.24.1"
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/${CALICO_VERSION}/manifests/tigera-operator.yaml

kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/${CALICO_VERSION}/manifests/custom-resources.yaml

watch kubectl get tigerastatus

watch kubectl get pods -n calico-system

## download calicoctl
sudo curl -L https://github.com/projectcalico/calico/releases/download/${CALICO_VERSION}/calicoctl-linux-amd64 -o /usr/local/bin/calicoctl
sudo chmod +x /usr/local/bin/calicoctl

# metallb
kubectl get configmap kube-proxy -n kube-system -o yaml | sed -e 's/mode: ""/mode: "ipvs"/' | sed -e "s/strictARP: false/strictARP: true/" | kubectl apply -f - -n kube-system

export METALLB_VERSION="v0.13.5"
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/${METALLB_VERSION}/config/manifests/metallb-native.yaml

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
export NGINX_INGRESS_VERSION="v1.3.1"
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-${NGINX_INGRESS_VERSION}/deploy/static/provider/baremetal/deploy.yaml

watch kubectl get pod -n ingress-nginx

# Stackgres
kubectl apply -f 'https://sgres.io/install'

kubectl apply -f - <<EOF
apiVersion: v1
kind: Service
metadata:
  namespace: stackgres
  name: stackgres-restapi
  annotations:
    meta.helm.sh/release-name: stackgres-operator
    meta.helm.sh/release-namespace: stackgres
  labels:
    app.kubernetes.io/managed-by: Helm
spec:
  type: LoadBalancer
  loadBalancerIP: 172.16.254.20
  selector:
    app: stackgres-restapi
  ports:
    - name: https
      protocol: TCP
      port: 443
      targetPort: https
EOF

watch kubectl get deploy,pod,svc -n stackgres

export HISTFILESIZE=0
NEW_USER=""
NEW_PASSWORD=""
kubectl create secret generic -n stackgres stackgres-restapi --dry-run=client -o json \
  --from-literal=k8sUsername="$NEW_USER" \
  --from-literal=password="$(echo -n "${NEW_USER}${NEW_PASSWORD}"| sha256sum | awk '{ print $1 }' )" > password.patch

kubectl patch secret -n stackgres stackgres-restapi -p "$(cat password.patch)" && rm password.patch

kubectl patch secrets --namespace stackgres stackgres-restapi --type json -p '[{"op":"remove","path":"/data/clearPassword"}]'
```

## Local manifests

```bash
kubectl apply -f sc.yml
```

### Minecraft
```bash
kubectl create namespace mc

kubectl create secret generic --namespace mc --from-file=./.secrets/mc_rcon_password mc-secret
kubectl create secret generic --namespace mc --from-file=./.secrets/mc_whitelist mc-whitelist
kubectl apply -f mc.yml
```

### Nextcloud
```bash
kubectl create namespace nextcloud

```

