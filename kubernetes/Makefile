K3S_HOST		:= k3s
K3S_VPS_HOST	:= k3s-oci.akashisn.info
K8S_HOST		:= k8s-v132-control-plane

.PHONY: app-k3s
app-k3s:
	cd $(CURDIR) ; \
	cat application.yml | ssh $(K3S_HOST) kubectl apply -f -

.PHONY: app-k3s-vps
app-k3s-vps:
	cd $(CURDIR) ; \
	cat application.yml | ssh $(K3S_VPS_HOST) kubectl apply -f -

.PHONY: app-k8s
app-k8s:
	cd $(CURDIR) ; \
	cat application.yml | ssh $(K8S_HOST) kubectl apply -f -

.PHONY: delete-app-k3s
delete-app-k3s:
	cd $(CURDIR) ; \
	cat application.yml | ssh $(K3S_HOST) kubectl delete -f -

.PHONY: delete-app-k3s-vps
delete-app-k3s-vps:
	cd $(CURDIR) ; \
	cat application.yml | ssh $(K3S_VPS_HOST) kubectl delete -f -

.PHONY: delete-app-k8s
delete-app-k8s:
	cd $(CURDIR) ; \
	cat application.yml | ssh $(K8S_HOST) kubectl delete -f -
