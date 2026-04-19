K3S_VPS_HOST	:= `sed -n '/k3s-vps:/,/^ *ansible_host: /s/^ *ansible_host: *\([^ ]*\).*/\1/p' inventory.yml`

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
