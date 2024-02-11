K3S_HOST			:= `sed -n '/k3s:/,/^ *ansible_host: /s/^ *ansible_host: *\([^ ]*\).*/\1/p' inventory.yml`
K3S_VPS_HOST	:= `sed -n '/k3s-vps:/,/^ *ansible_host: /s/^ *ansible_host: *\([^ ]*\).*/\1/p' inventory.yml`
K8S_HOST			:= `sed -n '/master-node:/,/^ *ansible_host: /s/^ *ansible_host: *\([^ ]*\).*/\1/p' inventory.yml`

.PHONY: clean
clean:
	rm -f $(CURDIR)/host_vars/k3s/vault.yml
	rm -f $(CURDIR)/host_vars/master-node/vault.yml

.PHONY: credential
credential:
	pass infra/ansible/vault.yml > $(CURDIR)/host_vars/k3s/vault.yml
	pass infra/ansible/vault.yml > $(CURDIR)/host_vars/k3s-vps/vault.yml
	pass infra/ansible/vault.yml > $(CURDIR)/host_vars/master-node/vault.yml

.PHONY: k3s
k3s:
	cd $(CURDIR) ; \
	ansible-playbook setup-k3s.yml

.PHONY: k3s-vps
k3s-vps:
	cd $(CURDIR) ; \
	ansible-playbook setup-k3s-vps.yml

.PHONY: k8s
k8s:
	cd $(CURDIR) ; \
	ansible-playbook setup-cluster.yml

.PHONY: app-k3s
app-k3s:
	cd $(CURDIR) ; \
	cat manifests/application.yml | ssh $(K3S_HOST) kubectl apply -f -

.PHONY: app-k3s-vps
app-k3s-vps:
	cd $(CURDIR) ; \
	sed -r -e '/kustomize:/,/^[^ ]/s/^(\s+)# /\1/' manifests/application.yml | ssh $(K3S_VPS_HOST) kubectl apply -f -

.PHONY: app-k8s
app-k8s:
	cd $(CURDIR) ; \
	cat manifests/application.yml | ssh $(K8S_HOST) kubectl apply -f -

.PHONY: delete-app-k3s
delete-app-k3s:
	cd $(CURDIR) ; \
	cat manifests/application.yml | ssh $(K3S_HOST) kubectl delete -f -

.PHONY: delete-app-k3s-vps
delete-app-k3s-vps:
	cd $(CURDIR) ; \
	sed -r -e '/kustomize:/,/^[^ ]/s/^(\s+)# /\1/' manifests/application.yml | ssh $(K3S_VPS_HOST) kubectl delete -f -

.PHONY: delete-app-k8s
delete-app-k8s:
	cd $(CURDIR) ; \
	cat manifests/application.yml | ssh $(K8S_HOST) kubectl delete -f -
