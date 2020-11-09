#!/bin/bash

if [ $# -ne 6 ]; then
  echo "usage: $0 <State Name> <Locality Name> <Organization Name> <Passphrase> <FQDN> <Clinet 1 2..>"
  exit 1;
fi

ST=$1
L=$2
O=$3
PP=$4
FQDN=$5
CLIENTS=($6)

CATOP="./demoCA"
SERVER_CERT_DIR=${SERVER_CERT_DIR:-"./cert/server"}
CLIENT_CERT_DIR=${CLIENT_CERT_DIR:-"./cert/client"}

rm -rf "${CATOP}"

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
openssl ec -in "${CATOP}/private/cakey.pem" -passout pass:"$PP" -out "${CATOP}/private/cakey_enc.pem" -aes256
mv "${CATOP}/private/cakey_enc.pem" "${CATOP}/private/cakey.pem"

# Create a certificate request
SJ="/C=JP/ST=$ST/L=$L/O=$O/CN=root"
openssl req -new -key "${CATOP}/private/cakey.pem" -passin pass:"$PP" -sha256 -out "${CATOP}/careq.pem" -subj "$SJ"

# Create self sign certificate
openssl ca -batch -create_serial -out "${CATOP}/cacert.pem" -days 1095 -keyfile "${CATOP}/private/cakey.pem" -passin pass:"$PP" -selfsign -extensions v3_ca -infiles "${CATOP}/careq.pem"

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
SJ="/C=JP/ST=$ST/L=$L/O=$O/CN=$FQDN"
openssl req -new -key newkey.pem -sha256 -out newreq.pem -subj "$SJ"

# Sign a certificate request
openssl ca -batch -policy policy_anything -passin pass:"$PP" -out newcert.pem -days 1095 -infiles newreq.pem

mv newcert.pem ${SERVER_CERT_DIR}/server.pem
mv newkey.pem ${SERVER_CERT_DIR}/server.key

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
	SJ="/C=JP/ST=$ST/L=$L/O=$O/CN=$CLIENT"
	openssl req -new -key newkey.pem -sha256 -out newreq.pem -subj "$SJ"

	# Sign a certificate request
	openssl ca -batch -policy policy_anything -passin pass:"$PP" -out newcert.pem -days 1095 -infiles newreq.pem

	mv newcert.pem "${CLIENT_CERT_DIR}/${CLIENT}.pem"
	mv newkey.pem "${CLIENT_CERT_DIR}/${CLIENT}.key"
done

echo
echo "Generate tls-auth key"
echo
openvpn --genkey secret ${SERVER_CERT_DIR}/ta.key
