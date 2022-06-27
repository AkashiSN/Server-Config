# Server-Config

## 前提
SSH keyでログインできる状態

## 環境構築
[Setup.md](docs/Setup.md)を参照

## コンテナの準備

`.env`を以下のように作成
```env
# mysql-epgstation
MYSQL_EPGSTATION_USER="epgstation"
MYSQL_EPGSTATION_PASSWORD="epgstation"
MYSQL_EPGSTATION_ROOT_PASSWORD="epgstation"
MYSQL_EPGSTATION_DATABASE="epgstation"

# epgstation
RECODED_PATH="/mnt/recorded/"

# mysql-nextcloud
MYSQL_NEXTCLOUD_USER="nextcloud"
MYSQL_NEXTCLOUD_PASSWORD="nextcloud"
MYSQL_NEXTCLOUD_ROOT_PASSWORD="nextcloud"
MYSQL_NEXTCLOUD_DATABASE="nextcloud"

# redis
REDIS_HOST_PASSWORD="redis"

# nextcloud
NEXTCLOUD_ADMIN_USER="admin"
NEXTCLOUD_ADMIN_PASSWORD="pass"
NAS_PATH="/mnt"

# samba
SAMBA_PASSWORD="samba"
SAMBA_PATH="/mnt/samba"

# Domain
DOMAIN="akashisn.info"
TV_SUBDOMAIN="tv"
FILES_SUBDOMAIN="files"

# IP
LOCAL_IP=192.168.1.1
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
docker compose exec -u www-data nextcloud php /var/www/html/occ config:app:set files max_chunk_size --value 524288000
docker compose exec -u www-data nextcloud php /var/www/html/occ log:file --file=/var/promtail/nextcloud/nextcloud.log
```

## コンテナの起動

```bash
sudo docker compose up -d
```
