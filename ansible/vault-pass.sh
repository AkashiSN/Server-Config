#!/bin/sh

aws --profile sylc ssm get-parameter \
  --name /ansible/k3s_cluster/vault_password \
  --with-decryption \
  --query Parameter.Value \
  --output text
