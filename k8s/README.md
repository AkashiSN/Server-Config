# Setup
## Environment
- Ubuntu 22.04

## Install k8s

```bash
ansible-playbook setup.yml
```

## Before shutdown

```bash
sudo service kube-shutdown stop
```

## After power on
### Monitoring

- Restart
```bash
kubectl patch daemonset loki-canary -n monitoring --type json -p='[{"op": "remove", "path": "/spec/template/spec/nodeSelector/non-existing"}]'
kubectl patch daemonset loki-logs -n monitoring --type json -p='[{"op": "remove", "path": "/spec/template/spec/nodeSelector/non-existing"}]'
kubectl patch daemonset prometheus-prometheus-node-exporter -n monitoring --type json -p='[{"op": "remove", "path": "/spec/template/spec/nodeSelector/non-existing"}]'
kubectl patch daemonset promtail -n monitoring --type json -p='[{"op": "remove", "path": "/spec/template/spec/nodeSelector/non-existing"}]'

kubectl scale deployment grafana -n monitoring --replicas=1
kubectl scale deployment loki-gateway -n monitoring --replicas=1
kubectl scale deployment loki-grafana-agent-operator -n monitoring --replicas=1
kubectl scale deployment prometheus-kube-state-metrics -n monitoring --replicas=1
kubectl scale deployment prometheus-prometheus-pushgateway -n monitoring --replicas=1
kubectl scale deployment prometheus-server -n monitoring --replicas=1

kubectl scale statefulset loki -n monitoring --replicas=1
kubectl scale statefulset prometheus-alertmanager -n monitoring --replicas=1

kubectl get all -n monitoring
```

### DNS
```bash
kubectl get -n dns pod,svc
```

- Restart
```bash
kubectl patch cronjobs dns-cronjob -n dns -p '{"spec" : {"suspend" : false }}'
```

### Minecraft

```bash
kubectl get pod,svc -n minecraft
kubectl logs -f -n minecraft minecraft-vanilla-0
kubectl exec -it -n minecraft minecraft-vanilla-0 -- bash
```

- Restart
```bash
kubectl scale statefulset minecraft-vanilla -n minecraft --replicas=1
```

### Nextcloud

```bash
kubectl get -n nextcloud pod
kubectl describe -n nextcloud pod nextcloud-0
kubectl logs -f -n nextcloud nextcloud-0 -c nextcloud
kubectl exec -it -n nextcloud nextcloud-0 -c nextcloud -- bash
kubectl exec -it -n nextcloud nextcloud-0 -c nextcloud -- /bin/sh -c 'su www-data --shel=/bin/sh --command="/usr/local/bin/php occ <command>"'
```

- Restart
```bash
kubectl scale deployment nextcloud-redis -n nextcloud --replicas=1
kubectl scale statefulset nextcloud-mariadb -n nextcloud --replicas=1
kubectl scale statefulset nextcloud -n nextcloud --replicas=1
kubectl patch cronjobs nextcloud-cronjob -n nextcloud -p '{"spec" : {"suspend" : false }}'
```

### Wordpress

```bash
kubectl get -n wordpress pod,svc
kubectl describe -n wordpress pod wordpress-0
kubectl logs -f -n wordpress wordpress-mariadb-0
kubectl logs -f -n wordpress wordpress-0 -c wordpress
kubectl exec -it -n wordpress wordpress-0 -c wordpress -- bash
kubectl exec -it -n wordpress wordpress-0 -c wordpress -- /bin/sh -c 'su www-data --shel=/bin/sh --command="wp <command>"'
```

- Restart
```bash
kubectl scale deployment wordpress-redis -n wordpress --replicas=1
kubectl scale statefulset wordpress-mariadb -n wordpress --replicas=1
kubectl scale statefulset wordpress -n wordpress --replicas=1
kubectl patch cronjobs wordpress-cronjob -n wordpress -p '{"spec" : {"suspend" : false }}'
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