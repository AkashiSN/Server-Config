# Setup

## Let's Encrypt

```bash
# Nginx reload script
cat <<'EOF' | tee /etc/letsencrypt/renewal-hooks/deploy/nginx-reload.sh
#!/bin/bash

NGINX_CONTAINER_ID=$(docker ps --filter name=compose-nginx --format {{.ID}})
if [[ -n ${NGINX_CONTAINER_ID} ]]; then
	docker exec compose-nginx-1 nginx -s reload
fi
EOF
chmod +x /etc/letsencrypt/renewal-hooks/deploy/nginx-reload.sh
```

# Run

```bash
docker compose --profile tunnel up -d
docker compose --profile tv up -d
```