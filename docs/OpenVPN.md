## Install

```bash
# Install openvpn
sudo apt install -y openvpn
```

## Setup

```bash
# Set OPENVPN_DIR env.
export OPENVPN_DIR=/etc/openvpn
```

```bash
# Set env file.
cat ${OPENVPN_DIR}/.openvpn.env
```

```bash
STATE_NAME="Osaka"
LOCALITY_NAME="Suita"
ORGANIZATION_NAME="Sylc"
ROOT_CA_PASSPHRASE="pass"
FQDN="host"
FQDN1="host1"
CLIENTS="iPadPro11 iPhone7 Pixel3XL MacBookPro13 Nexus5X Pixel4"
```

```bash
cat ${OPENVPN_DIR}/openvpn.sh
```

```bash
#!/bin/bash

source ${OPENVPN_DIR}/.openvpn.env

STATE_NAME="${STATE_NAME}"
LOCALITY_NAME="${LOCALITY_NAME}"
ORGANIZATION_NAME="${ORGANIZATION_NAME}"
ROOT_CA_PASSPHRASE="${ROOT_CA_PASSPHRASE}"
FQDN="${FQDN}"
FQDN1="${FQDN1}"
CLIENTS=(${CLIENTS})

CATOP="${OPENVPN_DIR}/demoCA"
SERVER_CERT_DIR="${OPENVPN_DIR}/server"
CLIENT_CERT_DIR="${OPENVPN_DIR}/client"
CLIENT_CONFIG_DIR="${OPENVPN_DIR}/client"

function clean() {
	# clean
	rm -f newreq.pem
	rm -rf "${CATOP}"
	rm -f $SERVER_CERT_DIR/*
	rm -f $CLIENT_CERT_DIR/*
	rm -f $CLIENT_CONFIG_DIR/*

	# create the directory hierarchy
	mkdir "${CATOP}"
	mkdir "${CATOP}/certs"
	mkdir "${CATOP}/crl"
	mkdir "${CATOP}/newcerts"
	mkdir "${CATOP}/private"
	touch "${CATOP}/index.txt"
	echo "01" > "${CATOP}/crlnumber"
}

#
# Root CA
#
function generate_rootCA() {
	echo
	echo "Making Root CA certificate ..."
	echo
	# Generate private key
	openssl ecparam -genkey -name prime256v1 -noout -out "${CATOP}/private/cakey.pem"
	openssl ec -in "${CATOP}/private/cakey.pem" -passout pass:"$ROOT_CA_PASSPHRASE" -out "${CATOP}/private/cakey_enc.pem" -aes256
	mv "${CATOP}/private/cakey_enc.pem" "${CATOP}/private/cakey.pem"

	# Create a certificate request
	SJ="/C=JP/ST=$STATE_NAME/L=$LOCALITY_NAME/O=$ORGANIZATION_NAME/CN=root"
	openssl req -new -key "${CATOP}/private/cakey.pem" -passin pass:"$ROOT_CA_PASSPHRASE" -sha256 -out "${CATOP}/careq.pem" -subj "$SJ"

	# Create self sign certificate
	openssl ca -batch -create_serial -out "${CATOP}/cacert.pem" -days 1095 -keyfile "${CATOP}/private/cakey.pem" -passin pass:"$ROOT_CA_PASSPHRASE" -selfsign -extensions v3_ca -infiles "${CATOP}/careq.pem"

	echo "Root CA certificate is in ${CATOP}/cacert.pem"

	cp "${CATOP}/cacert.pem" ${SERVER_CERT_DIR}/cacert.pem
	cp "${CATOP}/private/cakey.pem" ${SERVER_CERT_DIR}/cakey.pem
}

#
# Server certificate
#
function generate_server() {
	echo
	echo "Making Server certificate ..."
	echo
	# Generate private key
	openssl ecparam -genkey -name prime256v1 -noout -out newkey.pem

	# Create a certificate request
	SJ="/C=JP/ST=$STATE_NAME/L=$LOCALITY_NAME/O=$ORGANIZATION_NAME/CN=$FQDN"
	openssl req -new -key newkey.pem -sha256 -out newreq.pem -subj "$SJ"

	# Sign a certificate request
	openssl ca -batch -policy policy_anything -passin pass:"$ROOT_CA_PASSPHRASE" -out newcert.pem -days 1095 -infiles newreq.pem

	mv newcert.pem ${SERVER_CERT_DIR}/server.pem
	mv newkey.pem ${SERVER_CERT_DIR}/server.key
}

function generate_keys() {
	#
	# Diffie-Hellman (DH) key
	#

	openssl dhparam -out "${SERVER_CERT_DIR}/dh.pem" -2 4096

	#
	# TLS-Auth key
	#

	openvpn --genkey --secret ${SERVER_CERT_DIR}/ta.key
}


#
# Clinet certificate
#
function generate_client() {
	echo
	echo "$1 certificate"
	echo
	# Generate private key
	openssl ecparam -genkey -name prime256v1 -noout -out newkey.pem

	# Create a certificate request
	SJ="/C=JP/CN=$1"
	openssl req -new -key newkey.pem -sha256 -out newreq.pem -subj "$SJ"

	# Sign a certificate request
	openssl ca -batch -policy policy_anything -passin pass:"$ROOT_CA_PASSPHRASE" -out newcert.pem -days 1095 -infiles newreq.pem

	mv newcert.pem "${CLIENT_CERT_DIR}/${1}.pem"
	mv newkey.pem "${CLIENT_CERT_DIR}/${1}.key"

	cat << EOS > ${CLIENT_CONFIG_DIR}/${1}.ovpn
client
nobind
dev tun
remote-cert-tls server
remote ${FQDN} 1194 udp
remote ${FQDN1} 443 tcp
redirect-gateway def1

auth SHA256
cipher AES-256-GCM

<key>
$(cat ${CLIENT_CERT_DIR}/${1}.key)
</key>
<cert>
$(openssl x509 -in ${CLIENT_CERT_DIR}/${1}.pem)
</cert>
<ca>
$(openssl x509 -in ${SERVER_CERT_DIR}/cacert.pem)
</ca>
key-direction 1
<tls-auth>
$(cat ${SERVER_CERT_DIR}/ta.key)
</tls-auth>
EOS
}

function generate_clients() {
	echo
	echo "Making client certificate ..."
	echo
	for CLIENT in "${CLIENTS[@]}"; do
		generate_client ${CLIENT}
	done
}

if [ $1 == "add_client" ]; then
	generate_client $2
else
	clean
	generate_rootCA
	generate_server
	generate_keys
	generate_clients
fi
```

```bash
sudo /bin/bash ${OPENVPN_DIR}/openvpn.sh
```

### Add Client

```bash
sudo /bin/bash ${OPENVPN_DIR}/openvpn.sh add_client "client name"
```

## Server config

```bash
# Set env.
export OPENVPN_DIR=/etc/openvpn
export OPENVPN_IP=10.254.3.0

# Configure server.
cat << EOS > ${OPENVPN_DIR}/server/vpn.conf
topology subnet
server ${OPENVPN_IP} 255.255.255.0
verb 3

key ${OPENVPN_DIR}/server/server.key
ca ${OPENVPN_DIR}/server/cacert.pem
cert ${OPENVPN_DIR}/server/server.pem
dh ${OPENVPN_DIR}/server/dh.pem
tls-auth ${OPENVPN_DIR}/server/ta.key

client-config-dir ${OPENVPN_DIR}/client

auth SHA256
cipher AES-256-GCM

key-direction 0
keepalive 10 60
persist-key
persist-tun

port 443
proto tcp
dev tun0

push "dhcp-option DNS 8.8.8.8"
push "dhcp-option DNS 8.8.4.4"

user nobody
group nogroup
```

```bash
# Enable service.
sudo systemctl enable openvpn-server@vpn
```

## Start, Stop

```bash
# Start openvpn.
sudo systemctl start openvpn-server@vpn

# Stop openvpn.
sudo systemctl stop openvpn-server@vpn
```