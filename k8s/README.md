# Setup
## Environment
- Ubuntu 22.04

## Install k8s

```bash
ansible-playbook main.yml
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