.PHONY: clean
clean:
	rm -f $(CURDIR)/../../terraform/aws/.env
	rm -f $(CURDIR)/.kubeconfig

../../terraform/aws/.env:
	cd $(CURDIR)/../../terraform/aws/; \
	$(MAKE) .env

.kubeconfig: ../../terraform/aws/.env
	@. $(CURDIR)/../../terraform/aws/.env; \
	aws eks update-kubeconfig --kubeconfig .kubeconfig --name su-nishi_eks-auto-mode

.PHONY: app
app:
	@. $(CURDIR)/../../terraform/aws/.env; \
	cd $(CURDIR) ; \
	kubectl --kubeconfig .kubeconfig apply -k .
