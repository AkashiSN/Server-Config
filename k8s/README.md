```bash
kubectl apply -f sc-lv.yml
```

```bash
kubectl create namespace mc
kubectl create secret generic --namespace mc --from-file=./.secrets/mc_rcon_password mc-secret
kubectl create secret generic --namespace mc --from-file=./.secrets/mc_whitelist mc-whitelist
kubectl apply -f mc.yml
```