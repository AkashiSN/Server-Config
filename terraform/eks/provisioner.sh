#!/bin/bash
set -eux

k8s_version="1.31"
export AWS_DEFAULT_REGION=ap-northeast-1

# Install ssm-agent
sudo snap install amazon-ssm-agent --classic

# Install nodeadm
sudo curl "https://hybrid-assets.eks.amazonaws.com/releases/latest/bin/linux/amd64/nodeadm" -o /usr/local/bin/nodeadm
sudo chmod +x /usr/local/bin/nodeadm

# Install cluster via nodeadm
sudo nodeadm install "${k8s_version}" --credential-provider ssm

# Move nodeConfig.yaml
sudo mv /tmp/nodeConfig.yaml /root/nodeConfig.yaml

# Init hybrid node via nodeadm
sudo nodeadm init -c file:///root/nodeConfig.yaml

# debug hybrid node via nodeadm
sudo nodeadm debug -c file:///root/nodeConfig.yaml

echo "✅ Completed Successfully"
