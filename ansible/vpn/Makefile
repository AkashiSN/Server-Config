.PHONY: clean
clean:
	rm -f $(CURDIR)/host_vars/vpn-server/vault.yml

.PHONY: credential
credential:
	pass infra/ansible/vpn/vault.yml > $(CURDIR)/host_vars/vpn-server/vault.yml

.PHONY: vpn
vpn:
	cd $(CURDIR) ; \
	ansible-playbook setup-vpn.yml
