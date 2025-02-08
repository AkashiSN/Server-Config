K3S_HOST := k3s
K8S_HOST := k8s-v131-control-plane

.PHONY: k8s
k8s:
	cd $(CURDIR) ; \
	ansible-playbook setup-cluster.yml

.PHONY: app-k3s
app-k3s:
	cd $(CURDIR) ; \
	cat manifests/application.yml | ssh $(K3S_HOST) kubectl apply -f -

.PHONY: app-k8s
app-k8s:
	cd $(CURDIR) ; \
	cat manifests/application.yml | ssh $(K8S_HOST) kubectl apply -f -

.PHONY: delete-app-k3s
delete-app-k3s:
	cd $(CURDIR) ; \
	cat manifests/application.yml | ssh $(K3S_HOST) kubectl delete -f -

.PHONY: delete-app-k8s
delete-app-k8s:
	cd $(CURDIR) ; \
	cat manifests/application.yml | ssh $(K8S_HOST) kubectl delete -f -
