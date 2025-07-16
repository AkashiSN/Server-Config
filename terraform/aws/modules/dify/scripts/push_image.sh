#!/bin/bash
set -ex

# Setting alias
alias docker="sudo docker"

# Docker login
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com

# API
# Pull,push image (amd64)
docker pull --platform linux/amd64 langgenius/dify-api:$DIFY_API_VERSION
docker tag langgenius/dify-api:$DIFY_API_VERSION $DIFY_API_REPO_URL:$DIFY_API_VERSION-amd64
docker push $DIFY_API_REPO_URL:$DIFY_API_VERSION-amd64
# Pull,push image (arm64)
docker pull --platform linux/arm64 langgenius/dify-api:$DIFY_API_VERSION
docker tag langgenius/dify-api:$DIFY_API_VERSION $DIFY_API_REPO_URL:$DIFY_API_VERSION-arm64
docker push $DIFY_API_REPO_URL:$DIFY_API_VERSION-arm64
# Create manifest
docker manifest create --amend $DIFY_API_REPO_URL:$DIFY_API_VERSION $DIFY_API_REPO_URL:$DIFY_API_VERSION-amd64 $DIFY_API_REPO_URL:$DIFY_API_VERSION-arm64
# Push manifest
docker manifest push $DIFY_API_REPO_URL:$DIFY_API_VERSION

# Web
# Pull,push image (amd64)
docker pull --platform linux/amd64 langgenius/dify-web:$DIFY_WEB_VERSION
docker tag langgenius/dify-web:$DIFY_WEB_VERSION $DIFY_WEB_REPO_URL:$DIFY_WEB_VERSION-amd64
docker push $DIFY_WEB_REPO_URL:$DIFY_WEB_VERSION-amd64
# Pull,push image (arm64)
docker pull --platform linux/arm64 langgenius/dify-web:$DIFY_WEB_VERSION
docker tag langgenius/dify-web:$DIFY_WEB_VERSION $DIFY_WEB_REPO_URL:$DIFY_WEB_VERSION-arm64
docker push $DIFY_WEB_REPO_URL:$DIFY_WEB_VERSION-arm64
# Create manifest
docker manifest create --amend $DIFY_WEB_REPO_URL:$DIFY_WEB_VERSION $DIFY_WEB_REPO_URL:$DIFY_WEB_VERSION-amd64 $DIFY_WEB_REPO_URL:$DIFY_WEB_VERSION-arm64
# Push manifest
docker manifest push $DIFY_WEB_REPO_URL:$DIFY_WEB_VERSION

# Sandbox
# Pull,push image (amd64)
docker pull --platform linux/amd64 langgenius/dify-sandbox:$DIFY_SANDBOX_VERSION
docker tag langgenius/dify-sandbox:$DIFY_SANDBOX_VERSION $DIFY_SANDBOX_REPO_URL:$DIFY_SANDBOX_VERSION-amd64
docker push $DIFY_SANDBOX_REPO_URL:$DIFY_SANDBOX_VERSION-amd64
# Pull,push image (arm64)
docker pull --platform linux/arm64 langgenius/dify-sandbox:$DIFY_SANDBOX_VERSION
docker tag langgenius/dify-sandbox:$DIFY_SANDBOX_VERSION $DIFY_SANDBOX_REPO_URL:$DIFY_SANDBOX_VERSION-arm64
docker push $DIFY_SANDBOX_REPO_URL:$DIFY_SANDBOX_VERSION-arm64
# Create manifest
docker manifest create --amend $DIFY_SANDBOX_REPO_URL:$DIFY_SANDBOX_VERSION $DIFY_SANDBOX_REPO_URL:$DIFY_SANDBOX_VERSION-amd64 $DIFY_SANDBOX_REPO_URL:$DIFY_SANDBOX_VERSION-arm64
# Push manifest
docker manifest push $DIFY_SANDBOX_REPO_URL:$DIFY_SANDBOX_VERSION

# Plugin daemon
# Pull,push image (amd64)
docker pull --platform linux/amd64 langgenius/dify-plugin-daemon:$DIFY_PLUGIN_DAEMON_VERSION
docker tag langgenius/dify-plugin-daemon:$DIFY_PLUGIN_DAEMON_VERSION $DIFY_PLUGIN_DAEMON_REPO_URL:$DIFY_PLUGIN_DAEMON_VERSION-amd64
docker push $DIFY_PLUGIN_DAEMON_REPO_URL:$DIFY_PLUGIN_DAEMON_VERSION-amd64
# Pull,push image (arm64)
docker pull --platform linux/arm64 langgenius/dify-plugin-daemon:$DIFY_PLUGIN_DAEMON_VERSION
docker tag langgenius/dify-plugin-daemon:$DIFY_PLUGIN_DAEMON_VERSION $DIFY_PLUGIN_DAEMON_REPO_URL:$DIFY_PLUGIN_DAEMON_VERSION-arm64
docker push $DIFY_PLUGIN_DAEMON_REPO_URL:$DIFY_PLUGIN_DAEMON_VERSION-arm64
# Create manifest
docker manifest create --amend $DIFY_PLUGIN_DAEMON_REPO_URL:$DIFY_PLUGIN_DAEMON_VERSION $DIFY_PLUGIN_DAEMON_REPO_URL:$DIFY_PLUGIN_DAEMON_VERSION-amd64 $DIFY_PLUGIN_DAEMON_REPO_URL:$DIFY_PLUGIN_DAEMON_VERSION-arm64
# Push manifest
docker manifest push $DIFY_PLUGIN_DAEMON_REPO_URL:$DIFY_PLUGIN_DAEMON_VERSION
