VAULT_GROUPS := common argocd juicefs postgres_backup immich nextcloud

.PHONY: clean
clean:
	@for g in $(VAULT_GROUPS); do \
	  rm -f $(CURDIR)/group_vars/k3s_cluster/vault_$$g.yml; \
	done

.PHONY: credential
credential:
	@for g in $(VAULT_GROUPS); do \
	  aws --profile sylc ssm get-parameter \
	    --name /ansible/k3s_cluster/vault/$$g \
	    --with-decryption \
	    --query Parameter.Value \
	    --output text \
	    > $(CURDIR)/group_vars/k3s_cluster/vault_$$g.yml; \
	done

.PHONY: k3s-cluster
k3s-cluster:
	cd $(CURDIR) ; \
	ansible-playbook setup-k3s-cluster.yml
