# Setup
## Environment
- Ubuntu 22.04

## Install k8s
```bash
# become root
sudo su

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

# Install kubelet kubeadm kubectl
export K8S_APT_VERSION="$(apt-cache show kubelet | grep Version | grep ${K8S_MAJOR_VERSION} | head -n 1 | cut -d ' ' -f 2)"

apt-get install -y "kubelet=${K8S_APT_VERSION}" "kubeadm=${K8S_APT_VERSION}" "kubectl=${K8S_APT_VERSION}"

apt-mark hold kubelet kubeadm kubectl

# IF use Wireguard network
export NODE_IP="$(ip a s dev wg0 | sed -nE -e 's/ *inet ([0-9.]*).*/\1/p')"
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

# Disable DNS stub resolve
sed -i -e "s/.*DNSStubListener=yes/DNSStubListener=no/" /etc/systemd/resolved.conf
cd /etc
ln -sf ../run/systemd/resolve/resolv.conf resolv.conf
systemctl restart systemd-resolved.service
cd

# upgrade
apt-get update
apt-get upgrade -y

# reboot
reboot

# upgrade
sudo apt-get update
sudo apt-get upgrade -y

# reboot
sudo reboot
```

Only master-node
```bash
# IF use Wireguard network
export NODE_IP="$(ip a s dev wg0 | sed -nE -e 's/ *inet ([0-9.]*).*/\1/p')"

cat <<EOF > config.yml
apiVersion: kubeadm.k8s.io/v1beta3
kind: InitConfiguration
localAPIEndpoint:
  advertiseAddress: "${NODE_IP}"
  bindPort: 6443
---
apiVersion: kubeadm.k8s.io/v1beta3
kind: ClusterConfiguration
controlPlaneEndpoint: "${NODE_IP}"
networking:
  serviceSubnet: "10.96.0.0/16"
  podSubnet: "10.244.0.0/16"
---
apiVersion: kubelet.config.k8s.io/v1beta1
kind: KubeletConfiguration
serverTLSBootstrap: true
rotateCertificates: true
EOF

# k8s init
sudo kubeadm init --config=config.yml

mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

pending_csr=($(kubectl get csr | grep Pending | cut -d " " -f 1))
for csr in "${pending_csr[@]}" ; do
  kubectl certificate approve "${csr}"
done

kubectl get nodes -o wide
```

```bash
# helm
helm repo add stable https://charts.helm.sh/stable
helm repo update

# Calico
helm repo add projectcalico https://projectcalico.docs.tigera.io/charts
helm repo update

# https://projectcalico.docs.tigera.io/getting-started/kubernetes/helm
export CALICO_VERSION="v3.25.0"
helm install calico projectcalico/tigera-operator --version ${CALICO_VERSION} \
  --set installation.enabled="false" --namespace tigera-operator --create-namespace

kubectl apply -f - <<EOF
apiVersion: operator.tigera.io/v1
kind: Installation
metadata:
  name: default
spec:
  calicoNetwork:
    mtu: 1370
    ipPools:
    - blockSize: 26
      cidr: 10.244.0.0/16
      encapsulation: VXLANCrossSubnet
      natOutgoing: Enabled
      nodeSelector: all()
# IF use Wireguard network
    nodeAddressAutodetectionV4:
      firstFound: false
      cidrs:
        - "10.10.0.0/24"
EOF

watch kubectl get pods -n calico-system
kubectl get nodes -o wide

# Install calicoctl
curl -L https://github.com/projectcalico/calico/releases/download/${CALICO_VERSION}/calicoctl-linux-amd64 -o kubectl-calico
curl -L https://github.com/projectcalico/calico/releases/download/${CALICO_VERSION}/calicoctl-linux-amd64 -o calicoctl
chmod +x kubectl-calico calicoctl
sudo mv kubectl-calico calicoctl /usr/local/bin/

kubectl calico create -f - <<EOF
apiVersion: projectcalico.org/v3
kind: BGPConfiguration
metadata:
  name: default
spec:
  asNumber: 65000
  nodeToNodeMeshEnabled: false
  serviceExternalIPs:
  - cidr: 10.0.1.0/24
EOF

kubectl calico create -f - <<EOF
apiVersion: projectcalico.org/v3
kind: BGPPeer
metadata:
  name: mainrouter
spec:
  asNumber: 65000
  peerIP: 10.10.0.1
EOF

sudo calicoctl node status

# nginx-ingress
helm repo add nginx-stable https://helm.nginx.com/stable
helm repo update

# https://docs.nginx.com/nginx-ingress-controller/technical-specifications/
export NGINX_INGRESS_VERSION="0.16.0"
helm install nginx-ingress nginx-stable/nginx-ingress \
  --set "controller.service.type"="LoadBalancer" \
  --set "controller.service.externalTrafficPolicy"="Local" \
  --set "controller.service.externalIPs[0]"="10.0.1.100" \
  --version ${NGINX_INGRESS_VERSION} --namespace ingress-nginx --create-namespace

watch kubectl get pod,svc -n ingress-nginx

# cert manager
helm repo add jetstack https://charts.jetstack.io
helm repo update

# https://artifacthub.io/packages/helm/cert-manager/cert-manager
export CERT_MANAGER_VERSION="v1.11.0"
helm install cert-manager jetstack/cert-manager \
  --version ${CERT_MANAGER_VERSION} --namespace cert-manager \
  --create-namespace --set installCRDs=true

watch kubectl get deploy,svc,pod -n cert-manager

# ACME
export HISTSIZE=0
export HISTFILESIZE=0
EMAIL=""
TOKEN=""
kubectl apply -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: cloudflare-api-token-secret
  namespace: cert-manager
type: Opaque
stringData:
  api-token: ${TOKEN}
---
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-cluster-issuer
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    preferredChain: ISRG Root X1
    email: ${EMAIL}
    privateKeySecretRef:
      name: acme-client-letsencrypt
    solvers:
      - dns01:
          cloudflare:
            apiTokenSecretRef:
              name: cloudflare-api-token-secret
              key: api-token
EOF

# Metrics Server
helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/
helm repo update

# https://github.com/kubernetes-sigs/metrics-server/releases
export METRICS_SERVER_VERSION="3.8.3"
helm install metrics-server metrics-server/metrics-server \
  --version ${METRICS_SERVER_VERSION} --namespace kube-system

kubectl top node

# Prometheus operator
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

cat .secrets/grafana_admin_password

export PROMETHEUS_STACK_VERSION="44.2.1"
helm install prometheus-stack prometheus-community/kube-prometheus-stack  \
  --version ${PROMETHEUS_STACK_VERSION} --namespace monitoring \
  --create-namespace \
  --set "grafana.adminPassword=$(cat .secrets/grafana_admin_password)" \
  --set "grafana.ingress.enabled=true" \
  --set "grafana.ingress.ingressClassName=nginx" \
  --set "grafana.ingress.annotations.cert-manager\.io/cluster-issuer=letsencrypt-cluster-issuer" \
  --set "grafana.ingress.hosts[0]=dash.akashisn.info" \
  --set "grafana.ingress.tls[0].secretName=letsencrypt-cert" \
  --set "grafana.ingress.tls[0].hosts[0]=dash.akashisn.info"

kubectl -n monitoring get pods,svc,ing

# Restart coredns
kubectl -n kube-system rollout restart deployment coredns

# reboot
sudo reboot
```

## Local manifests

```bash
kubectl apply -f storage-class.yml
```

### DNS
```bash
kubectl create namespace dns

kubectl apply -f dns/dns.yml

kubectl get -n dns pod,svc
```

### Minecraft

- minecraft_rcon_password
- minecraft_whitelist

```bash
kubectl create namespace minecraft

kubectl create secret generic --namespace minecraft --from-file=./.secrets/minecraft_rcon_password minecraft-secrets
kubectl create secret generic --namespace minecraft --from-file=./.secrets/minecraft_whitelist minecraft-whitelist

kubectl apply -f minecraft/persistent-volume.yml
kubectl apply -f minecraft/minecraft.yml

kubectl get pod -n minecraft
kubectl logs -f -n minecraft minecraft-vanilla-0
kubectl exec -it -n minecraft minecraft-vanilla-0 -- bash
```

- Stop
```bash
kubectl scale statefulset minecraft-vanilla -n minecraft --replicas=0
```

- Restart
```bash
kubectl scale statefulset minecraft-vanilla -n minecraft --replicas=1
```

### Nextcloud

- nextcloud_admin_user
- nextcloud_admin_password
- nextcloud_mariadb_root_password
- nextcloud_mariadb_user_password
- nextcloud_smtp_user
- nextcloud_smtp_password

```bash
kubectl create namespace nextcloud

kubectl create secret generic --namespace nextcloud --from-file=./.secrets/nextcloud_admin_user --from-file=./.secrets/nextcloud_admin_password --from-file=./.secrets/nextcloud_mariadb_root_password --from-file=./.secrets/nextcloud_mariadb_user_password --from-file=./.secrets/nextcloud_smtp_user --from-file=./.secrets/nextcloud_smtp_password nextcloud-secrets

kubectl apply -f nextcloud/persistent-volume.yml
kubectl apply -f nextcloud/redis.yml
kubectl apply -f nextcloud/mariadb.yml
kubectl apply -f nextcloud/nginx-conf.yml
kubectl apply -f nextcloud/nextcloud.yml
kubectl apply -f nextcloud/cronjob.yml

kubectl get -n nextcloud pod
kubectl describe -n nextcloud pod nextcloud-0
kubectl logs -f -n nextcloud nextcloud-0 -c nextcloud
kubectl exec -it -n nextcloud nextcloud-0 -c nextcloud -- bash
kubectl exec -it -n nextcloud nextcloud-0 -c nextcloud -- /bin/sh -c 'su www-data --shel=/bin/sh --command="/usr/local/bin/php occ <command>"'
```

- Stop
```bash
kubectl patch cronjobs nextcloud-cronjob -n nextcloud -p "{\"spec\" : {\"suspend\" : true }}"
kubectl scale statefulset nextcloud -n nextcloud --replicas=0
kubectl scale statefulset nextcloud-mariadb -n nextcloud --replicas=0
kubectl scale deployment nextcloud-redis -n nextcloud --replicas=0
```

- Restart
```bash
kubectl scale deployment nextcloud-redis -n nextcloud --replicas=1
kubectl scale statefulset nextcloud-mariadb -n nextcloud --replicas=1
kubectl scale statefulset nextcloud -n nextcloud --replicas=1
kubectl patch cronjobs nextcloud-cronjob -n nextcloud -p "{\"spec\" : {\"suspend\" : false }}"
```

### Wordpress
- wordpress_mariadb_root_password
- wordpress_mariadb_user_password
- wordpress_admin_user
- wordpress_admin_password
- wordpress_admin_email

```bash
kubectl create namespace wordpress

kubectl create secret generic --namespace wordpress --from-file=./.secrets/wordpress_mariadb_root_password --from-file=./.secrets/wordpress_mariadb_user_password --from-file=./.secrets/wordpress_admin_user --from-file=./.secrets/wordpress_admin_password --from-file=./.secrets/wordpress_admin_email wordpress-secrets

kubectl apply -f wordpress/persistent-volume.yml
kubectl apply -f wordpress/mariadb.yml
kubectl apply -f wordpress/redis.yml
kubectl apply -f wordpress/nginx-conf.yml
kubectl apply -f wordpress/wordpress.yml
kubectl apply -f wordpress/cronjob.yml

kubectl get -n wordpress pod
kubectl describe -n wordpress pod wordpress-0
kubectl logs -f -n wordpress wordpress-mariadb-0
kubectl logs -f -n wordpress wordpress-0 -c wordpress
kubectl exec -it -n wordpress wordpress-0 -c wordpress -- bash
kubectl exec -it -n wordpress wordpress-0 -c wordpress -- /bin/sh -c 'su www-data --shel=/bin/sh --command="wp <command>"'
```

### Buiildkit

```bash
kubectl create namespace buildkit

cd buildkit/.certs/
  $env:CAROOT=$(pwd)
  mkcert -cert-file daemon/cert.pem -key-file daemon/key.pem build.akashisn.info
  mkcert -client -cert-file client/cert.pem -key-file client/key.pem client
  cp rootCA.pem daemon/ca.pem
  cp rootCA.pem client/ca.pem
  rm -fo rootCA.pem,rootCA-key.pem

  kubectl create secret generic --namespace buildkit --from-file=./daemon buildkit-daemon-certs

  # docker biuldx
  docker buildx create --name buildkit --driver remote  --driver-opt "cacert=$(pwd)/client/ca.pem,cert=$(pwd)/client/cert.pem,key=$(pwd)/client/key.pem,servername=build.akashisn.info" tcp://build.akashisn.info:2376 --use
cd ../..

kubectl apply -f buildkit/buildkit.yml

kubectl get pod,svc -n buildkit
```

### Registry

- registry_http_secrets
- registry_htapasswd : `htpasswd -B -C 12 -c .htapasswd <user>`

```bash
kubectl create namespace registry

kubectl create secret generic --namespace registry --from-file=./.secrets/registry_http_secrets --from-file=./.secrets/registry_htapasswd registry-secrets

kubectl apply -f registry/persistent-volume.yml
kubectl apply -f registry/registry.yml
kubectl apply -f registry/cronjob.yml

kubectl get -n registry pod,svc
kubectl exec -it -n registry registry-0 --  registry garbage-collect /etc/docker/registry/config.yml
```

# Upgrade kubelet

```bash
sudo su

export K8S_MAJOR_VERSION="1.26"
export K8S_APT_VERSION="$(apt-cache show kubelet | grep Version | grep ${K8S_MAJOR_VERSION} | head -n 1 | cut -d ' ' -f 2)"

apt-mark unhold kubelet kubeadm kubectl

apt-get install -y "kubelet=${K8S_APT_VERSION}" "kubeadm=${K8S_APT_VERSION}" "kubectl=${K8S_APT_VERSION}"

apt-mark hold kubelet kubeadm kubectl

```

Only master-node
```bash
kubeadm upgrade plan

kubeadm upgrade apply VERSION
```