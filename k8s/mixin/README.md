## Build prometheus config

```bash
jb install github.com/kubernetes-monitoring/kubernetes-mixin

jsonnet -J vendor -S -e 'std.manifestYamlDoc((import "mixin.libsonnet").prometheusAlerts)' | yq e 'del(.groups[] | select(.name == "kubernetes-system-kube-proxy"))' > prometheus_alerts.yml
jsonnet -J vendor -S -e 'std.manifestYamlDoc((import "mixin.libsonnet").prometheusRules)' | yq > prometheus_rules.yml
jsonnet -J vendor -m dashboards -e '(import "mixin.libsonnet").grafanaDashboards'
rm dashboards/proxy.json
```