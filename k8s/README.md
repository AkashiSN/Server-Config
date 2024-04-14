# Setup
## Environment
- Ubuntu 22.04

## Install

```bash
make k8s or k3s
make app-k8s or app-k3s
```

## Before shutdown

```bash
make delete-app-k3s or make delete-app-k8s
```

## After power on

```bash
make app-k8s or app-k3s
```

## Node maintenance

```bash
kubectl drain worker-node-01 --ignore-daemonsets --delete-emptydir-data
kubectl get pod -A -o wide --watch
# maintenance e.g. update, reboot
kubectl uncordon worker-node-01
```

### DNS

[![argo-cd](https://argocd.akashisn.info/api/badge?name=dns&revision=true)](https://argocd.akashisn.info/applications/argo-cd/dns)

```bash
kubectl get -n dns pod,svc
```

### Minecraft

[![argo-cd](https://argocd.akashisn.info/api/badge?name=minecraft&revision=true)](https://argocd.akashisn.info/applications/argo-cd/minecraft)

```bash
kubectl get pod,svc -n minecraft
kubectl logs -f -n minecraft minecraft-vanilla-0
kubectl exec -it -n minecraft minecraft-vanilla-0 -- bash
```

### Palworld

[![argo-cd](https://argocd.akashisn.info/api/badge?name=palworld&revision=true)](https://argocd.akashisn.info/applications/argo-cd/palworld)

```bash
kubectl get pod,svc -n palworld
kubectl logs -f -n palworld palworld-server-0
kubectl exec -it -n palworld palworld-server-0 -- bash
```

### Nextcloud

[![argo-cd](https://argocd.akashisn.info/api/badge?name=nextcloud&revision=true)](https://argocd.akashisn.info/applications/argo-cd/nextcloud)

```bash
kubectl get -n nextcloud pod
kubectl describe -n nextcloud pod nextcloud-0
kubectl logs -f -n nextcloud nextcloud-0 --tail 10 -c nextcloud
kubectl exec -it -n nextcloud nextcloud-0 -c nextcloud -- bash
kubectl exec -it -n nextcloud nextcloud-0 -c nextcloud -- /bin/sh -c 'su www-data --shel=/bin/sh --command="/usr/local/bin/php occ <command>"'
```

### Wordpress

[![argo-cd](https://argocd.akashisn.info/api/badge?name=wordpress&revision=true)](https://argocd.akashisn.info/applications/argo-cd/wordpress)

```bash
kubectl get -n wordpress pod,svc
kubectl describe -n wordpress pod wordpress-0
kubectl logs -f -n wordpress wordpress-0 --tail 10 -c wordpress
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

## Debug

```yml
image: busybox
command: ["/bin/sh", "-c", "sleep infinity"]
```

### Renew certificate

```bash
kubectl get cert,cr,order,challenge,secret
kubectl delete cert <certname>
kubectl delete secret <secretname>
```


### Switch production to k3s

```
interface Tunnel0.0

no ip napt static 172.16.254.100 tcp 80
no ip napt static 172.16.254.100 tcp 443
no ip napt static 172.16.254.110 udp 53
no ip napt static 172.16.254.110 tcp 853
no ip napt static 172.16.254.120 tcp 25565
no ip napt static 172.16.254.125 udp 8211

ip napt static 172.16.254.50 tcp 80
ip napt static 172.16.254.50 tcp 443
ip napt static 172.16.254.60 udp 53
ip napt static 172.16.254.60 tcp 853
ip napt static 172.16.254.70 tcp 25565
ip napt static 172.16.254.75 udp 8211

exit
```

### Switch k3s to production

```
interface Tunnel0.0

no ip napt static 172.16.254.50 tcp 80
no ip napt static 172.16.254.50 tcp 443
no ip napt static 172.16.254.60 udp 53
no ip napt static 172.16.254.60 tcp 853
no ip napt static 172.16.254.70 tcp 25565
no ip napt static 172.16.254.75 udp 8211

ip napt static 172.16.254.100 tcp 80
ip napt static 172.16.254.100 tcp 443
ip napt static 172.16.254.110 udp 53
ip napt static 172.16.254.110 tcp 853
ip napt static 172.16.254.120 tcp 25565
ip napt static 172.16.254.125 udp 8211

exit
```