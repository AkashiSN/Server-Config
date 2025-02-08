AWS_PROFILE:="cdx-pre-dev"

.PHONY: clean
clean:
	rm -rf $(CURDIR)/.tmp
	rm -f $(CURDIR)/.env
	rm -f $(CURDIR)/*.tfvars*
	rm -f $(CURDIR)/*.tfstate*

.env:
	@unset AWS_ACCESS_KEY_ID; \
	unset AWS_SECRET_ACCESS_KEY; \
	unset AWS_SESSION_TOKEN; \
	\
	echo "Fetching MFA device serial number for the user..."; \
	UserName=$$(pass infra/aws/$(AWS_PROFILE)/iam-user 2>/dev/null); \
	SerialNumber=$$(aws --profile $(AWS_PROFILE) iam list-mfa-devices --user-name $$UserName | jq -r '.MFADevices[].SerialNumber'); \
	echo "MFA Serial Number: $$SerialNumber"; \
	read -p 'Enter MFA Code: ' code; \
	aws --profile $(AWS_PROFILE) sts get-session-token --serial-number $$SerialNumber --token-code $$code > $(CURDIR)/.credential; \
	\
	echo "export AWS_ACCESS_KEY_ID=$$(cat $(CURDIR)/.credential | jq -r '.Credentials.AccessKeyId')" > $(CURDIR)/.env; \
	echo "export AWS_SECRET_ACCESS_KEY=$$(cat $(CURDIR)/.credential | jq -r '.Credentials.SecretAccessKey')" >> $(CURDIR)/.env; \
	echo "export AWS_SESSION_TOKEN=$$(cat $(CURDIR)/.credential | jq -r '.Credentials.SessionToken')" >> $(CURDIR)/.env;\
	\
	rm $(CURDIR)/.credential; \
	\
	echo "Environment variables have been saved to .env. Run 'source .env' to load them into your shell."

terraform.tfvars:
	@echo "homelab_global_ip_address=\"$$(pass infra/homelab/global-ip-address 2>/dev/null)\"" > $(CURDIR)/terraform.tfvars
	@echo "iam_user=\"$$(pass infra/aws/$(AWS_PROFILE)/iam-user 2>/dev/null)\"" >> $(CURDIR)/terraform.tfvars
	@echo "email=\"$$(pass email 2>/dev/null)\"" >> $(CURDIR)/terraform.tfvars

.PHONY: aws
aws: terraform.tfvars .env
	@. $(CURDIR)/.env; \
	terraform apply
