# Setup
## Environment
- Ubuntu 22.04

## Install

```bash
make k3s-vps
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
