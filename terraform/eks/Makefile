AWS_REGION:=ap-northeast-1
AWS_PROFILE:=cdx-pre-dev
AWS_ACCOUNT_ID:=$$(aws sts get-caller-identity | jq -r '.Account')

EKS_HYBRID_ROLE:=su-nishi_role-eks-hybrid-nodes
EKS_CLUSTER_NAME:=su-nishi_eks-hybrid-nodes

VM_HYBRID_NODE_HOST:=eks-v131-hybrid-node-01

define NODE_CONFIG_YAML
apiVersion: node.eks.aws/v1alpha1
kind: NodeConfig
spec:
  cluster:
    name: $(EKS_CLUSTER_NAME)
    region: $(AWS_REGION)
  hybrid:
    ssm:
      activationId: $(shell cat .activation | jq -r '.ActivationId')
      activationCode: $(shell cat .activation | jq -r '.ActivationCode')
endef
export NODE_CONFIG_YAML

.PHONY: clean
clean:
	rm -rf $(CURDIR)/.tmp
	rm -f $(CURDIR)/.activation
	rm -f $(CURDIR)/nodeConfig.yaml
	rm -f $(CURDIR)/*.tfvars*
	rm -f $(CURDIR)/*.tfstate*

terraform.tfvars:
	pass infra/terraform/tfvars > $(CURDIR)/terraform.tfvars

.PHONY: vm
vm: terraform.tfvars
	terraform apply

../aws/.env:
	cd $(CURDIR)/../aws/; \
	$(MAKE) aws-credential

.activation: ../aws/.env
	@. $(CURDIR)/../aws/.env; \
	echo "Create activation for EKS hybrid nodes..."; \
	aws ssm create-activation \
	--region $(AWS_REGION) \
	--default-instance-name eks-hybrid-nodes \
	--description "Activation for EKS hybrid nodes" \
	--iam-role $(EKS_HYBRID_ROLE) \
	--tags Key=EKSClusterARN,Value=arn:aws:eks:$(AWS_REGION):$(AWS_ACCOUNT_ID):cluster/$(EKS_CLUSTER_NAME) \
	--registration-limit 10 > $(CURDIR)/.activation

nodeConfig.yaml: .activation
	echo "$$NODE_CONFIG_YAML" > $(CURDIR)/nodeConfig.yaml

.PHONY: install
install: nodeConfig.yaml
	scp nodeConfig.yaml $(VM_HYBRID_NODE_HOST):/tmp/nodeConfig.yaml
	cat provisioner.sh | ssh $(VM_HYBRID_NODE_HOST) /bin/bash -
