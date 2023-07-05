local kubernetes = import "kubernetes-mixin/mixin.libsonnet";

kubernetes {
  _config+:: {
    cadvisorSelector: 'job="kubernetes-nodes-cadvisor"',
    kubeletSelector: 'job="kubernetes-nodes"',
    kubeStateMetricsSelector: 'app_kubernetes_io_name="kube-state-metrics"',
    nodeExporterSelector: 'job="node-exporter"',
    kubeSchedulerSelector: 'job="kubernetes-pods",component="kube-scheduler"',
    kubeControllerManagerSelector: 'job="kubernetes-pods",component="kube-controller-manager"',
    kubeApiserverSelector: 'job="kubernetes-apiservers"',
    podLabel: 'pods',
    grafanaK8s+:: {
      grafanaTimezone: 'JST',
    },
  },
}