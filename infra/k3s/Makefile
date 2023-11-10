.PHONY: clean
clean:
	rm -rf $(CURDIR)/.tmp
	rm -f $(CURDIR)/*.tfvars*
	rm -f $(CURDIR)/*.tfstate*

.PHONY: credential
credential:
	pass infra/terraform/tfvars > $(CURDIR)/terraform.tfvars

.PHONY: vm
vm: clean credential
	cd $(CURDIR) ; \
	terraform plan && \
	terraform apply
