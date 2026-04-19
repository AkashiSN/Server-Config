# Kubernetes

このディレクトリは k3s-vps クラスタ上にデプロイするアプリケーション群のマニフェストを管理しています。

## 構成

| パス | 内容 | デプロイ方法 |
| --- | --- | --- |
| `application.yml` | Argo CD `AppProject` と `ApplicationSet`。dns / nextcloud / immich を自動同期 | `make app-k3s-vps` |
| `namespace.yml` | 各アプリ用の Namespace 定義 | `kubectl apply -f` |
| `storage-class.yml` | `local-storage` / `iscsi-{hdd,ssd}-storage` / `nfs-hdd-storage` の StorageClass。ansible の cluster role からも適用される | `kubectl apply -f` |
| `dns/` | CoreDNS ベースの内部 DNS | Argo CD 自動同期 |
| `immich/` | Immich (写真管理) + Postgres + Redis | Argo CD 自動同期 |
| `nextcloud/` | Nextcloud + MariaDB + Redis + Nginx | Argo CD 自動同期 |
| `minecraft/` | Minecraft server | `kubectl apply -k` |
| `tv/` | Mirakc + EPGStation + MariaDB | `kubectl apply -k` |
| `wordpress/` | WordPress + MariaDB + Redis + Nginx | `kubectl apply -k` |

## Deploy / Delete

### Argo CD ApplicationSet (dns / nextcloud / immich)

`application.yml` を k3s-vps クラスタに適用し、Argo CD 側で各アプリを自動同期します。

```bash
# Deploy
make app-k3s-vps

# Delete
make delete-app-k3s-vps
```

### 手動デプロイ (minecraft / tv / wordpress)

Argo CD の対象外なので kustomize で直接適用 / 削除します。

```bash
# Deploy
kubectl apply -k kubernetes/minecraft
kubectl apply -k kubernetes/tv
kubectl apply -k kubernetes/wordpress

# Delete
kubectl delete -k kubernetes/minecraft
kubectl delete -k kubernetes/tv
kubectl delete -k kubernetes/wordpress
```

## Applications

### DNS

[![argo-cd](https://argocd.akashisn.info/api/badge?name=dns&revision=true)](https://argocd.akashisn.info/applications/argo-cd/dns)

```bash
kubectl get -n dns pod,svc
```

### Immich

[![argo-cd](https://argocd.akashisn.info/api/badge?name=immich&revision=true)](https://argocd.akashisn.info/applications/argo-cd/immich)

```bash
kubectl get -n immich pod,svc
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

### Minecraft

[![argo-cd](https://argocd.akashisn.info/api/badge?name=minecraft&revision=true)](https://argocd.akashisn.info/applications/argo-cd/minecraft)

```bash
kubectl get pod,svc -n minecraft
kubectl logs -f -n minecraft minecraft-vanilla-0
kubectl exec -it -n minecraft minecraft-vanilla-0 -- bash
```

### TV (Mirakc + EPGStation)

```bash
kubectl get -n tv pod,svc
kubectl logs -f -n tv mirakc-0
kubectl logs -f -n tv epgstation-0
```

### WordPress

```bash
kubectl get -n wordpress pod,svc
kubectl describe -n wordpress pod wordpress-0
kubectl logs -f -n wordpress wordpress-0 --tail 10 -c wordpress
kubectl exec -it -n wordpress wordpress-0 -c wordpress -- bash
kubectl exec -it -n wordpress wordpress-0 -c wordpress -- /bin/sh -c 'su www-data --shel=/bin/sh --command="wp <command>"'
```

## Operations

### Debug Pod

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
