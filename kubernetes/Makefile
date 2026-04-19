K3S_VPS_HOST	:= k3s-oci.akashisn.info

.PHONY: app-k3s-vps
app-k3s-vps:
	cd $(CURDIR) ; \
	cat application.yml | ssh $(K3S_VPS_HOST) kubectl apply -f -

.PHONY: delete-app-k3s-vps
delete-app-k3s-vps:
	cd $(CURDIR) ; \
	cat application.yml | ssh $(K3S_VPS_HOST) kubectl delete -f -
