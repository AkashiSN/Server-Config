# Server-Config

## 前提
SSH keyでログインできる状態

## 環境構築
[Setup.md](docs/Setup.md)を参照

## コンテナの準備

`.env`を以下のように作成
```env
# www-data user
UID=33
GID=33

# mysql-epgstation
MYSQL_EPGSTATION_USER="epgstation"
MYSQL_EPGSTATION_PASSWORD="epgstation"
MYSQL_EPGSTATION_ROOT_PASSWORD="epgstation"
MYSQL_EPGSTATION_DATABASE="epgstation"

# epgstation
RECODED_PATH="/mnt/nas/recorded/"

# mysql-nextcloud
MYSQL_NEXTCLOUD_USER="nextcloud"
MYSQL_NEXTCLOUD_PASSWORD="nextcloud"
MYSQL_NEXTCLOUD_ROOT_PASSWORD="nextcloud"
MYSQL_NEXTCLOUD_DATABASE="nextcloud"

# redis
REDIS_HOST_PASSWORD="redis"

# nextcloud
NEXTCLOUD_ADMIN_USER="admin"
NEXTCLOUD_ADMIN_PASSWORD="path"
NAS_PATH="/mnt/nas"

# auth-proxy
SLACK_CLIENT_ID="hoge.hoge"
SLACK_CLIENT_SECRET=""

# Domain
DOMAIN="akashisn.info"
TV_SUBDOMAIN="tv"
FILES_SUBDOMAIN="files"
```

コンテナのビルドを行う

```bash
sudo docker-compose build
```

現在のユーザーをグループwww-dataに追加する

```bash
sudo usermod -a -G www-data user
sudo usermod -a -G user www-data
```

### OpenVPN用の証明書の作成

`openvpn/.openvpn.env`というファイルを以下のように作成する
```env
# OpenVPN
STATE_NAME="Osaka"
LOCALITY_NAME="Suita"
ORGANIZATION_NAME="Sylc"
ROOT_CA_PASSPHRASE="hogehoge"
FQDN=""
CLIENTS="iPadPro11 iPhone7 Pixel3XL MacBookPro13"
```

```bash
# Create certificate
sudo docker-compose run --rm --entrypoint=/opt/openvpn/openssl.sh openvpn
```

## チューナ周波数の設定

Many thanks: https://qiita.com/KouCo/items/69bcacbf867366e5d692

手動でチャンネルの周波数の設定を行う場合

```bash
cd mirakurun/scan

sudo docker build -t dvb-scan --target=dvb-tools .
sudo docker run --rm -it --device /dev/dvb:/dev/dvb --cap-add SYS_ADMIN --cap-add SYS_NICE -v `pwd`/tuners:/workdir/tuners dvb-scan

cd ../..
```

## コンテナの起動

```bash
sudo docker-compose up
```
