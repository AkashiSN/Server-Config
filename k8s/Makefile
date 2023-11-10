K3S_HOST := k3s
K8S_HOST := k8s-control-plane

.PHONY: clean
clean:
	rm -f $(CURDIR)/host_vars/k3s/vault.yml
	rm -f $(CURDIR)/host_vars/master-node/vault.yml

.PHONY: credential
credential:
	pass infra/ansible/vault.yml > $(CURDIR)/host_vars/k3s/vault.yml
	pass infra/ansible/vault.yml > $(CURDIR)/host_vars/master-node/vault.yml

.PHONY: k3s
k3s:
	cd $(CURDIR) ; \
	ansible-playbook setup-k3s.yml

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
