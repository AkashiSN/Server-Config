# Setup
## Environment
- Ubuntu 22.04

## Install k8s

```bash
sudo su

bash ./install.sh

reboot

sudo apt-get update
sudo apt-get upgrade -y
```

Only master-node
```bash
# network
export INTERFACE="$(ip route show default | sed -nE -e 's/.*dev (\w+).*/\1/p')"
export NODE_IP="$(ip addr show dev ${INTERFACE} | sed -nE -e 's/.+inet ([0-9.]+).+/\1/p')"
export NODE_NETWORK="$(ip route show dev ${INTERFACE} | sed -nE -e 's/([0-9.]+\.0\/[0-9]+).+/\1/p')"

export INTERFACE_V6="$(ip -6 route show default | sed -nE -e 's/.*dev (\w+).*/\1/p')"
export NODE_IP_V6="$(ip -6 addr show dev ${INTERFACE_V6}| sed -nE -e 's/.+inet6 ([^(fe80)][0-9a-f:]+).+/\1/p')"
export NODE_NETWORK_V6="$(ip -6 route show dev ${INTERFACE_V6} | sed -nE -e 's/([^(fe80)][0-9a-f:]+::\/[0-9]+).+/\1/p')"
export IPV6_PREFIX="$(ip -6 route show dev ${INTERFACE_V6} | sed -nE -e 's/(^[^(fe80)][0-9a-f:]+)::.+/\1/p')"

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
  podSubnet: "10.244.0.0/16,${IPV6_PREFIX}:cafe:0::/96"
  serviceSubnet: "10.96.0.0/16,${IPV6_PREFIX}:cafe:1::/112"
controllerManager:
  extraArgs:
    node-cidr-mask-size-ipv4: "24"
    node-cidr-mask-size-ipv6: "112"
---
apiVersion: kubelet.config.k8s.io/v1beta1
kind: KubeletConfiguration
serverTLSBootstrap: true
rotateCertificates: true
EOF

# k8s init
sudo kubeadm init --skip-phases=addon/kube-proxy --config=config.yml

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

# cilium
helm repo add cilium https://helm.cilium.io/
helm repo update

helm install cilium cilium/cilium \
--namespace kube-system \
--set "kubeProxyReplacement=strict" \
--set "k8sServiceHost=${NODE_IP}" \
--set "k8sServicePort=6443" \
--set "ipv4.enabled=true" \
--set "ipv6.enabled=true" \
--set "ipam.mode=cluster-pool" \
--set "ipam.operator.clusterPoolIPv4PodCIDRList=10.244.0.0/16" \
--set "ipam.operator.clusterPoolIPv6PodCIDRList=${IPV6_PREFIX}:cafe:0::/96" \
--set "ipam.operator.clusterPoolIPv4MaskSize=24" \
--set "ipam.operator.clusterPoolIPv6MaskSize=112" \
--set "bpf.masquerade=true" \
--set "enableIPv6Masquerade=false"

watch kubectl -n kube-system get pods -l k8s-app=cilium

kubectl -n kube-system patch configmap/cilium-config --type merge \
  -p "{\"data\":{\"enable-ipv6-ndp\": \"true\", \"ipv6-service-range\": \"${IPV6_PREFIX}:cafe:1::/112\"}}"

kubectl -n kube-system rollout restart deploy cilium-operator
kubectl -n kube-system rollout restart daemonset cilium

watch kubectl -n kube-system get pod -o wide

# MetalLB
helm repo add metallb https://metallb.github.io/metallb
helm repo update

helm install metallb metallb/metallb --namespace kube-system

watch kubectl -n kube-system get pod -o wide

kubectl apply -f - <<EOF
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: default-pool
  namespace: kube-system
spec:
  addresses:
  - 172.16.254.100-172.16.254.150
  - ${IPV6_PREFIX}:ffff:fac:ade::/112
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: l2-ip
  namespace: kube-system
spec:
  ipAddressPools:
  - default-pool
EOF

# nginx-ingress
helm repo add nginx-stable https://helm.nginx.com/stable
helm repo update

# https://docs.nginx.com/nginx-ingress-controller/installation/installation-with-helm/
helm install nginx-ingress nginx-stable/nginx-ingress \
--set "controller.service.type=LoadBalancer" \
--set "controller.service.externalTrafficPolicy=Local" \
--set "controller.service.annotations.metallb\.universe\.tf/loadBalancerIPs=172.16.254.100\,${IPV6_PREFIX}:ffff:fac:ade:100" \
--set "controller.service.ipFamilyPolicy=RequireDualStack" \
--namespace nginx-ingress --create-namespace

watch kubectl get pod,svc -n nginx-ingress -o wide

# cert manager
helm repo add jetstack https://charts.jetstack.io
helm repo update

# https://artifacthub.io/packages/helm/cert-manager/cert-manager
helm install cert-manager jetstack/cert-manager --namespace cert-manager --create-namespace --set installCRDs=true

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
helm install metrics-server metrics-server/metrics-server --namespace kube-system

watch kubectl get deploy,svc,pod -n kube-system
kubectl top node

# Prometheus operator
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

cat .secrets/grafana_admin_password

helm install prometheus-stack prometheus-community/kube-prometheus-stack  \
--namespace monitoring --create-namespace \
--set "grafana.adminPassword=$(cat .secrets/grafana_admin_password)" \
--set "grafana.ingress.enabled=true" \
--set "grafana.ingress.ingressClassName=nginx" \
--set "grafana.ingress.annotations.cert-manager\.io/cluster-issuer=letsencrypt-cluster-issuer" \
--set "grafana.ingress.hosts[0]=dash.akashisn.info" \
--set "grafana.ingress.tls[0].secretName=letsencrypt-cert" \
--set "grafana.ingress.tls[0].hosts[0]=dash.akashisn.info"

watch kubectl -n monitoring get pods,svc,ing

# Restart coredns
kubectl -n kube-system rollout restart deployment coredns
kubectl get pod -n kube-system

# reboot
sudo reboot
```

## Local manifests

```bash
export INTERFACE_V6="$(ip -6 route show default | sed -nE -e 's/.*dev (\w+).*/\1/p')"
export IPV6_PREFIX="$(ip -6 route show dev ${INTERFACE_V6} | sed -nE -e 's/(^[^(fe80)][0-9a-f:]+)::.+/\1/p')"
```

```bash
kubectl apply -f storage-class.yml
```

### DNS
```bash
kubectl create namespace dns

kubectl apply -f dns/dns.yml

kubectl annotate -n dns svc dns-server "metallb.universe.tf/loadBalancerIPs=172.16.254.110,${IPV6_PREFIX}:ffff:fac:ade:110"

kubectl apply -f dns/cronjob.yml

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

kubectl get pod,svc -n minecraft
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
kubectl apply -f wordpress/redis.yml
kubectl apply -f wordpress/mariadb.yml
kubectl apply -f wordpress/nginx-conf.yml
kubectl apply -f wordpress/wordpress.yml
kubectl apply -f wordpress/cronjob.yml

kubectl get -n wordpress pod,svc
kubectl describe -n wordpress pod wordpress-0
kubectl logs -f -n wordpress wordpress-mariadb-0
kubectl logs -f -n wordpress wordpress-0 -c wordpress
kubectl exec -it -n wordpress wordpress-0 -c wordpress -- bash
kubectl exec -it -n wordpress wordpress-0 -c wordpress -- /bin/sh -c 'su www-data --shel=/bin/sh --command="wp <command>"'
```

### HackMD

- hackmd_mariadb_root_password
- hackmd_mariadb_user_password
- hackmd_mariadb_uri

```bash
cat <<EOF > .secrets/hackmd_mariadb_uri
mysql://hackmd:$(cat .secrets/hackmd_mariadb_user_password)@hackmd-mariadb:3306/hackmd
EOF

kubectl create namespace hackmd

kubectl create secret generic --namespace hackmd --from-file=./.secrets/hackmd_mariadb_root_password --from-file=./.secrets/hackmd_mariadb_user_password --from-file=./.secrets/hackmd_mariadb_uri hackmd-secrets

kubectl apply -f hackmd/persistent-volume.yml
kubectl apply -f hackmd/mariadb.yml
kubectl apply -f hackmd/hackmd.yml

kubectl get -n hackmd pod,svc,ing
kubectl logs -f -n hackmd hackmd-mariadb-0
kubectl logs -f -n hackmd hackmd-0
```

### Growi

- growi_mongodb_root_password
- growi_mongodb_user_password
- growi_mongodb_uri


```bash
cat <<EOF > .secrets/hackmd_mariadb_uri
mongodb://growi:$(cat .secrets/growi_mongodb_root_password)@growi-mongodb:27017/growi
EOF


kubectl create namespace growi

kubectl create secret generic --namespace growi --from-file=./.secrets/growi_mongodb_root_password --from-file=./.secrets/growi_mongodb_user_password --from-file=./.secrets/growi_mongodb_uri growi-secrets

kubectl apply -f growi/persistent-volume.yml
kubectl apply -f growi/redis.yml
kubectl apply -f growi/elasticsearch.yml
kubectl apply -f growi/mongodb.yml
kubectl apply -f growi/plantuml.yml
kubectl apply -f growi/growi.yml

kubectl get -n growi pod,svc,ing
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