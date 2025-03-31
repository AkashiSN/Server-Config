K3S_HOST := `sed -n '/k3s:/,/^ *ansible_host: /s/^ *ansible_host: *\([^ ]*\).*/\1/p' inventory.yml`
K8S_HOST := `sed -n '/master-node:/,/^ *ansible_host: /s/^ *ansible_host: *\([^ ]*\).*/\1/p' inventory.yml`

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
