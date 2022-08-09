# Server-Config

## 前提
SSH keyでログインできる状態

## 環境構築
[Setup.md](docs/Setup.md)を参照

## コンテナの準備

1. `.screts/`に以下のファイルを作成
- `.secrets/minio_access_key`
- `.secrets/minio_secret_key`
- `.secrets/mc_rcon_password`
- `.secrets/restic_password`
- `.secrets/postgres_nextcloud_password`
- `.secrets/nextcloud_admin_user`
- `.secrets/nextcloud_admin_password`
- `.secrets/nextcloud_smtp_password`

2. `.env`を以下のように作成
```bash
# mysql-epgstation
MYSQL_EPGSTATION_PASSWORD=""
MYSQL_EPGSTATION_ROOT_PASSWORD=""

# minecraft
MC_WHITELIST=""

# restic
RESTIC_REPOSITORY=""
MINIO_RESTIC_ACCESS_KEY=""
MINIO_RESTIC_SECRET_ACCESS_KEY=""

# redis
REDIS_HOST_PASSWORD=""

# nextcloud
NEXTCLOUD_SMTP_USER=""

# Domain
DOMAIN=""

# ddclient
CLOUDFLARE_TOKEN=""

# IP
LOCAL_IP=
DOCKER_IPV6_SUBNET=
```

```bash
sudo docker compose pull
```

現在のユーザーをグループwww-dataに追加する

```bash
sudo usermod -a -G www-data user
sudo usermod -a -G user www-data
```

### Nextcloud

https://developers.cloudflare.com/cache/about/default-cache-behavior#customization-options-and-limitations

```
docker compose exec -u www-data nextcloud php /var/www/html/occ log:file --file=/var/promtail/nextcloud/nextcloud.log
```

## コンテナの起動

```bash
sudo docker compose up -d
```
