# Server-Config

## 前提
SSH keyでログインできる状態

## 環境構築
[Setup.md](docs/Setup.md)を参照

## コンテナの準備

`.env`を以下のように作成
```bash
# mysql-epgstation
MYSQL_EPGSTATION_PASSWORD=""
MYSQL_EPGSTATION_ROOT_PASSWORD=""

# postgres-nextcloud
POSTGRES_NEXTCLOUD_PASSWORD=""

# redis
REDIS_HOST_PASSWORD=""

# nextcloud
NEXTCLOUD_ADMIN_USER=""
NEXTCLOUD_ADMIN_PASSWORD="v"
NEXTCLOUD_SMTP_USER=""
NEXTCLOUD_SMTP_PASSWORD=""

# minio
MINIO_ROOT_USER=""
MINIO_ROOT_PASSWORD=""
OBJECTSTORE_S3_KEY=""
OBJECTSTORE_S3_SECRET=""

# samba
SAMBA_PASSWORD=""

# Domain
DOMAIN=""

# IP
LOCAL_IP=
DOCKER_IPV6_SUBNET=
```

コンテナのビルドを行う

```bash
sudo docker compose build --pull
```

現在のユーザーをグループwww-dataに追加する

```bash
sudo usermod -a -G www-data user
sudo usermod -a -G user www-data
```

### Nextcloud

https://developers.cloudflare.com/cache/about/default-cache-behavior#customization-options-and-limitations

```
docker compose exec -u www-data nextcloud php /var/www/html/occ config:system:set default_phone_region --value=JP
docker compose exec -u www-data nextcloud php /var/www/html/occ config:app:set files max_chunk_size --value 1048576000
docker compose exec -u www-data nextcloud php /var/www/html/occ log:file --file=/var/promtail/nextcloud/nextcloud.log
```

## コンテナの起動

```bash
sudo docker compose up -d
```
