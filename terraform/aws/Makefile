AWS_PROFILE:="cdx-pre-dev"

.PHONY: clean
clean:
	rm -rf $(CURDIR)/.tmp
	rm -f $(CURDIR)/.env
	rm -f $(CURDIR)/*.tfvars*
	rm -f $(CURDIR)/*.tfstate*

terraform.tfvars:
	@echo "iam_user=\"$$(pass infra/aws/$(AWS_PROFILE)/iam-user 2>/dev/null)\"" >> $(CURDIR)/terraform.tfvars
