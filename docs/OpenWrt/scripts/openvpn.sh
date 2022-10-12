#!/bin/ash
set -e

OPENVPN_DIR=/etc/openvpn
cd "${OPENVPN_DIR}"

source ${OPENVPN_DIR}/.openvpn.env

CATOP="${OPENVPN_DIR}/demoCA"
SERVER_CERT_DIR="${OPENVPN_DIR}/server"
CLIENT_CERT_DIR="${OPENVPN_DIR}/client"
ROOT_CA_PASS_FILE="${OPENVPN_DIR}/root_ca_pass_phrase"

function clean() {
	# clean
	rm -f req.pem
	rm -rf "${CATOP}"
	rm -rf "${SERVER_CERT_DIR}"
	rm -rf "${CLIENT_CERT_DIR}"

	# create the directory hierarchy
	mkdir "${CATOP}"
	mkdir "${CATOP}/certs"
	mkdir "${CATOP}/crl"
	mkdir "${CATOP}/newcerts"
	mkdir "${CATOP}/private"
	touch "${CATOP}/index.txt"
	echo "01" > "${CATOP}/crlnumber"

	mkdir "${SERVER_CERT_DIR}"
	mkdir "${CLIENT_CERT_DIR}"
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

  # Add pass phrase to private key
	openssl ec -in "${CATOP}/private/cakey.pem" -passout "file:${ROOT_CA_PASS_FILE}" -out "${CATOP}/private/cakey_enc.pem" -aes256

  # Overwrite plain key by encrypted key
	mv "${CATOP}/private/cakey_enc.pem" "${CATOP}/private/cakey.pem"

	# Create a certificate request
	openssl req -new -key "${CATOP}/private/cakey.pem" -passin "file:${ROOT_CA_PASS_FILE}" -sha256 -out req.pem -subj "/CN=root"

	# Create self sign certificate
	openssl ca -batch -policy policy_anything -create_serial -keyfile "${CATOP}/private/cakey.pem" -passin "file:${ROOT_CA_PASS_FILE}" -out "${CATOP}/cacert.pem" -days 1095 -selfsign -extensions v3_ca -infiles req.pem
	rm -f req.pem

	echo "Root CA certificate is in ${CATOP}/cacert.pem,cakey.pem"
}

#
# Server certificate
#
function generate_server() {
	echo
	echo "Making Server certificate ..."
	echo

	# Generate private key
	openssl ecparam -genkey -name prime256v1 -noout -out "${SERVER_CERT_DIR}/server_key.pem"

	# Create a certificate request
	openssl req -new -key "${SERVER_CERT_DIR}/server_key.pem" -sha256 -out req.pem -subj "/CN=$FQDN"

	# Sign a certificate request
	openssl ca -batch -policy policy_anything -keyfile "${CATOP}/private/cakey.pem" -passin "file:${ROOT_CA_PASS_FILE}" -out "${SERVER_CERT_DIR}/server_cert.pem" -days 1095 -infiles req.pem
	rm -f req.pem

	echo "Server certificate is in ${SERVER_CERT_DIR}/server_cert.pem,server_key.pem"
}

function generate_keys() {
	echo
	echo "Generate key ..."
	echo

	#
	# Diffie-Hellman (DH) key
	#
	openssl dhparam -out "${SERVER_CERT_DIR}/dh.pem" -2 4096

	#
	# TLS-Crypt key
	#
	openvpn --genkey secret "${SERVER_CERT_DIR}/tls_crypt.key"

	echo "DH key and TLS-Crypt key is in ${SERVER_CERT_DIR}/dh.pem,tls_crypt.pem"
}

#
# Clinet certificate
#
function generate_client() {
	echo
	echo "Client $1 certificate"
	echo

	# Generate private key
	openssl ecparam -genkey -name prime256v1 -noout -out "${CLIENT_CERT_DIR}/${1}_key.pem"

	# Create a certificate request
	openssl req -new -key "${CLIENT_CERT_DIR}/${1}_key.pem" -sha256 -out req.pem -subj "/CN=$1"

	# Sign a certificate request
	openssl ca -batch -policy policy_anything -keyfile "${CATOP}/private/cakey.pem" -passin "file:${ROOT_CA_PASS_FILE}" -out "${CLIENT_CERT_DIR}/${1}_cert.pem" -days 1095 -infiles req.pem
	rm -f req.pem

	echo "Client $1 certificate is in ${CLIENT_CERT_DIR}/${1}_cert.pem,${1}_key.pem"
}

function generate_clients() {
	echo
	echo "Making client certificate ..."
	echo

	LENGTH=`echo ${CLIENTS} | tr ' ' '\n' | wc -l`
	for i in `seq ${LENGTH}`
	do
		CLIENT=`echo ${CLIENTS} | cut -d ' ' -f $i`
		generate_client "${CLIENT}"
	done
}

if [ "$1" = "add_client" ]; then
	CLIENTS="${CLIENTS} $2"
	cat << EOS > ${OPENVPN_DIR}/.openvpn.env
FQDN="${FQDN}"
CLIENTS="${CLIENTS}"
EOS
	generate_client "$2"
else
	clean
	generate_rootCA
	generate_server
	generate_keys
	generate_clients
fi