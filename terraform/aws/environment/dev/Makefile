.PHONY: clean
clean:
	rm -f $(CURDIR)/*.tfvars*

terraform.tfvars:
	@echo "iam_user=\"$$(aws iam get-user --query 'User.UserName' --output text 2>/dev/null)\"" >> $(CURDIR)/terraform.tfvars
