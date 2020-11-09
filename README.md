# Server-Config

## 前提
SSH keyでログインできる状態

## 環境構築
[Setup.md](docs/Setup.md)を参照

## コンテナの準備

`.env`を以下のように作成
```env
# mysql
MYSQL_USER="epgstation"
MYSQL_PASSWORD="epgstation"
MYSQL_ROOT_PASSWORD="epgstation"
MYSQL_DATABASE="epgstation"

# epgstation
RECODED_PATH=

# auth-proxy
SLACK_CLIENT_ID=

# Domain
DOMAIN="akashisn.info"
TV_SUBDOMAIN="tv"
```

コンテナのビルドを行う

```bash
sudo docker-compose build
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

## コンテナの起動

```bash
sudo docker-compose up
```
