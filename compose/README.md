# Setup

## Let's Encrypt

```bash
# Nginx reload script
cat <<'EOF' | tee /etc/letsencrypt/renewal-hooks/deploy/nginx-reload.sh
#!/bin/sh

NGINX_CONTAINER_ID=$(docker ps --filter name=compose-nginx --format {{.ID}})
if [[ -n ${NGINX_CONTAINER_ID} ]]; then
	docker exec compose-nginx-1 nginx -s reload
fi
EOF
```

## Cloudflared

```bash
curl -L --output cloudflared.deb https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb

sudo dpkg -i cloudflared.deb

unset HISTFILE
sudo cloudflared service install $TOKEN
```

# Run

```bash
docker compose --profile tv up -d
```