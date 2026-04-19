.PHONY: clean
clean:
	rm -f $(CURDIR)/host_vars/k3s-vps/vault.yml

.PHONY: credential
credential:
	op read "op://Private/ansible-vault/vault.yml" > $(CURDIR)/host_vars/k3s-vps/vault.yml

.PHONY: k3s-vps
k3s-vps:
	cd $(CURDIR) ; \
	ansible-playbook setup-k3s-vps.yml
