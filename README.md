# Server-Config

## 前提
SSH keyでログインできる状態

## 環境構築
[Setup.md](docs/Setup.md)を参照

## コンテナの準備

`.env`を以下のように作成
```env
FFMPEG_IMAGE=
SLACK_CLIENT_ID=
DOMAIN=
```

`.mariadb_epgstation.env`を以下で作成
```env
MYSQL_USER="epgstation"
MYSQL_PASSWORD="epgstation"
MYSQL_ROOT_PASSWORD="epgstation"
MYSQL_DATABASE="epgstation"
```

コンテナのビルドを行う

```bash
sudo docker-compose build
```

データベースのバックアップがあるなら、以下でリストアする
https://hub.docker.com/_/mariadb
```bash
sudo docker-compose up mariadb_epgstation

export MYSQL_ROOT_PASSWORD=
sudo -E docker-compose exec -T mariadb_epgstation sh -c 'exec mysql -uroot -p"$MYSQL_ROOT_PASSWORD"' < all-databases.sql
```

### OpenVPN用の証明書の作成
https://help.ui.com/hc/en-us/articles/115015971688-EdgeRouter-OpenVPN-Server
```bash
# Launch shell in openvpn container
sudo docker-compose run --rm --entrypoint bash openvpn

# Generate a Diffie-Hellman (DH) key
openssl dhparam -out ./cert/server/dh.pem -2 2048

# Generate a root certificate
./CA.pl -newca

# PEM Passphrase: <secret>
# Country Name: JP
# State Or Province Name: Osaka
# Locality Name: Suita
# Organization Name: Sylc
# Common Name: root

# Copy the newly created certificate + key to the OpenVPN directory
cp demoCA/cacert.pem ./cert/server/cacert.pem
cp demoCA/private/cakey.pem ./cert/server/cakey.pem

# Generate the server certificate
./CA.pl -newreq

# Country Name: JP
# State Or Province Name: Osaka
# Locality Name: Suita
# Organization Name: Sylc
# Common Name: <vpn host name>

# Sign the server certificate
./CA.pl -sign

# Move and rename the server certificate and key files to the OpenVPN directory
mv newcert.pem ./cert/server/server.pem
mv newkey.pem ./cert/server/server.key

# Generate tls-auth key
openvpn --genkey --secret ./cert/server/ta.key

# Generate, sign and move the certificate and key files for the first OpenVPN client
./CA.pl -newreq

# Common Name: <client name>

# Sign the client certificate
./CA.pl -sign

# Move and rename the client certificate and key files to the OpenVPN directory
mv newcert.pem ./cert/client/<client name>.pem
mv newkey.pem ./cert/client/<client name>.key

# Remove the password from the server key file and optionally the client key file(s)
openssl rsa -in ./cert/server/server.key -out ./cert/server/server-no-pass.key
openssl rsa -in ./cert/client/<client name>.key -out ./cert/client/<client name>-no-pass.key

# Overwrite the existing keys with the no-pass versions
mv ./cert/server/server-no-pass.key ./cert/server/server.key 
mv ./cert/client/<client name>-no-pass.key ./cert/client/<client name>.key 

# Add read permission for non-root users to the client key files
chmod 644 ./cert/client/<client name>.key
```

クライアント用の設定ファイルを以下のように作成する
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
