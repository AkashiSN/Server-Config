.PHONY: clean
clean:
	rm -f $(CURDIR)/group_vars/k3s_cluster/vault.yml

.PHONY: credential
credential:
	op read "op://Private/ansible-vault/vault.yml" > $(CURDIR)/group_vars/k3s_cluster/vault.yml

.PHONY: k3s-cluster
k3s-cluster:
	cd $(CURDIR) ; \
	ansible-playbook setup-k3s-cluster.yml
