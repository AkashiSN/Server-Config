.PHONY: clean
clean:
	rm -rf $(CURDIR)/.tmp
	rm -f $(CURDIR)/*.tfvars*
	rm -f $(CURDIR)/*.tfstate*

terraform.tfvars:
	pass infra/terraform/tfvars > $(CURDIR)/terraform.tfvars

.PHONY: vm
vm: terraform.tfvars
	terraform apply

../aws/.env:
	cd $(CURDIR)/../aws/; \
	$(MAKE) .env

.kubeconfig: ../aws/.env
	@. $(CURDIR)/../aws/.env; \
	aws eks update-kubeconfig --kubeconfig .kubeconfig --name su-nishi_eks-hybrid-nodes

.PHONY: install-cilium
install-cilium: .kubeconfig
	@. $(CURDIR)/../aws/.env; \
	helm --kubeconfig .kubeconfig \
		--repo https://helm.cilium.io/ \
		install cilium cilium \
		--version 1.16.5 \
    	--namespace kube-system \
    	--values cilium-values.yaml \
		--set k8sServiceHost=$(shell sed -n 's|.*server: https://\(.*\)$$|\1|p' .kubeconfig)
