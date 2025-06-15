.PHONY: clean
clean:
	rm -rf $(CURDIR)/.tmp
	rm -rf $(CURDIR)/.terraform
	rm -f $(CURDIR)/*.tfvars*
	rm -f $(CURDIR)/*.tfstate*

terraform.tfvars:
	pass infra/terraform/tfvars > $(CURDIR)/terraform.tfvars

.PHONY: vm
vm: terraform.tfvars
	terraform apply
