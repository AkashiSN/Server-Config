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
VPN_SUBDOMAIN="vpn"

# OpenVPN
STATE_NAME="Osaka"
LOCALITY_NAME="Suita"
ORGANIZATION_NAME="Sylc"
ROOT_CA_PASSPHRASE="hogehoge"
CLIENTS=""

```

コンテナのビルドを行う

```bash
sudo docker-compose build
```

### OpenVPN用の証明書の作成
クライアント用の設定ファイル(`<client name>.ovpn`)を以下のように作成する
```ovpn
client
dev tun
proto tcp
remote <server> 443
float
resolv-retry infinite
nobind
persist-key
persist-tun
verb 3
redirect-gateway def1

<ca>
  ./cert/server/cacert.pemの内容をコピペ
</ca>
<cert>
  ./cert/client/<client name>.pemの内容をコピペ
</cert>
<key>
  ./cert/client/<client name>.keyの内容をコピペ
</key>
<tls-auth>
  ./cert/server/ta.keyの内容をコピペ
</tls-auth>
```

## コンテナの起動

```bash
sudo docker-compose up
```
