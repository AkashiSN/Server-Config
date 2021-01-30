#!/bin/bash

source .openvpn.env

STATE_NAME=${1:-$STATE_NAME}
LOCALITY_NAME=${2:-$LOCALITY_NAME}
ORGANIZATION_NAME=${3:-$ORGANIZATION_NAME}
ROOT_CA_PASSPHRASE=${4:-$ROOT_CA_PASSPHRASE}
FQDN=${5:-$FQDN}
CLIENTS=(${6:-$CLIENTS})

CATOP="./demoCA"
SERVER_CERT_DIR=${SERVER_CERT_DIR:-"./cert/server"}
CLIENT_CERT_DIR=${CLIENT_CERT_DIR:-"./cert/client"}
CLIENT_CONFIG_DIR=${CLIENT_CONFIG_DIR:-"./config"}

# clean
rm -f newreq.pem
rm -rf "${CATOP}"
rm -f $SERVER_CERT_DIR/*
rm -f $CLIENT_CERT_DIR/*
rm -f $CLIENT_CONFIG_DIR/*

# Generate a Diffie-Hellman (DH) key
openssl dhparam -out "${SERVER_CERT_DIR}/dh.pem" -2 4096

# create the directory hierarchy
mkdir "${CATOP}"
mkdir "${CATOP}/certs"
mkdir "${CATOP}/crl"
mkdir "${CATOP}/newcerts"
mkdir "${CATOP}/private"
touch "${CATOP}/index.txt"
echo "01" > "${CATOP}/crlnumber"

#
# Root CA
#
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

#
# Server certificate
#

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

#
# TLS-Auth key
#

openvpn --genkey --secret ${SERVER_CERT_DIR}/ta.key

#
# Clinet certificate
#

echo
echo "Making client certificate ..."
echo
for CLIENT in "${CLIENTS[@]}"; do
	echo
	echo "$CLIENT certificate"
	echo
	# Generate private key
	openssl ecparam -genkey -name prime256v1 -noout -out newkey.pem

	# Create a certificate request
	SJ="/C=JP/CN=$CLIENT"
	openssl req -new -key newkey.pem -sha256 -out newreq.pem -subj "$SJ"

	# Sign a certificate request
	openssl ca -batch -policy policy_anything -passin pass:"$ROOT_CA_PASSPHRASE" -out newcert.pem -days 1095 -infiles newreq.pem

	mv newcert.pem "${CLIENT_CERT_DIR}/${CLIENT}.pem"
	mv newkey.pem "${CLIENT_CERT_DIR}/${CLIENT}.key"

	cat << EOS > ${CLIENT_CONFIG_DIR}/${CLIENT}.ovpn
client
nobind
dev tun
remote-cert-tls server
remote ${FQDN} 1194 udp
remote ${FQDN} 443 tcp
redirect-gateway def1

auth SHA256
cipher AES-256-GCM

<key>
$(cat ${CLIENT_CERT_DIR}/${CLIENT}.key)
</key>
<cert>
$(openssl x509 -in ${CLIENT_CERT_DIR}/${CLIENT}.pem)
</cert>
<ca>
$(openssl x509 -in ${SERVER_CERT_DIR}/cacert.pem)
</ca>
key-direction 1
<tls-auth>
$(cat ${SERVER_CERT_DIR}/ta.key)
</tls-auth>
EOS
done

