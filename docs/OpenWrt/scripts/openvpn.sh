#!/bin/ash
set -e -c

OPENVPN_DIR=/etc/openvpn
cd "${OPENVPN_DIR}"

source ${OPENVPN_DIR}/.openvpn.env

FQDN="${FQDN}"
CLIENTS=(${CLIENTS})

CATOP="${OPENVPN_DIR}/CA"
SERVER_CERT_DIR="${OPENVPN_DIR}/server"
CLIENT_CERT_DIR="${OPENVPN_DIR}/client"
ROOT_CA_PASS_FILE="${OPENVPN_DIR}/root_ca_pass_phrase"

function clean() {
	# clean
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

  cd "${CATOP}"

	# Generate private key
	openssl ecparam -genkey -name prime256v1 -noout -out private/ca_key.pem

  # Add pass phrase to private key
	openssl ec -in private/ca_key.pem -passout "file:${ROOT_CA_PASS_FILE}" -out private/ca_key_enc.pem -aes256

  # Overwrite plain key by encrypted key
	mv private/ca_key_enc.pem private/ca_key.pem

	# Create a certificate request
	openssl req -new -key private/ca_key.pem -passin "file:${ROOT_CA_PASS_FILE}" -sha256 -out ca_req.pem -subj "/CN=${FQDN}"

	# Create self sign certificate
	openssl ca -batch -policy policy_anything -create_serial -out ca_cert.pem -days 1095 -keyfile private/ca_key.pem -passin "file:${ROOT_CA_PASS_FILE}" -selfsign -extensions v3_ca -infiles ca_req.pem

	echo "Root CA certificate is in ${CATOP}/ca_cert.pem,ca_key.pem"
}

#
# Server certificate
#
function generate_server() {
	echo
	echo "Making Server certificate ..."
	echo

	cd "${SERVER_CERT_DIR}"

	# Generate private key
	openssl ecparam -genkey -name prime256v1 -noout -out server_key.pem

	# Create a certificate request
	openssl req -new -key server_key.pem -sha256 -out cert_req.pem -subj "/CN=$FQDN"

	# Sign a certificate request
	openssl ca -batch -policy policy_anything -passin "file:${ROOT_CA_PASS_FILE}" -out server_cert.pem -days 1095 -infiles cert_req.pem

	echo "Server certificate is in ${SERVER_CERT_DIR}/server_cert.pem,server_key.pem"
}

function generate_keys() {
	echo
	echo "Generate key ..."
	echo

	cd "${SERVER_CERT_DIR}"

	#
	# Diffie-Hellman (DH) key
	#
	openssl dhparam -out dh.pem -2 4096

	#
	# TLS-Crypt key
	#
	openvpn --genkey --secret tls_crypt.key

	echo "DH key and TLS-Crypt key is in ${SERVER_CERT_DIR}/dh.pem,tls_crypt.pem"
}

#
# Clinet certificate
#
function generate_client() {
	echo
	echo "Client $1 certificate"
	echo

	cd "${CLIENT_CERT_DIR}"

	# Generate private key
	openssl ecparam -genkey -name prime256v1 -noout -out "${1}_key.pem"

	# Create a certificate request
	openssl req -new -key "${1}_key.pem" -sha256 -out cert_req.pem -subj "/CN=$1"

	# Sign a certificate request
	openssl ca -batch -policy policy_anything -passin "file:${ROOT_CA_PASS_FILE}" -out "${1}_cert.pem" -days 1095 -infiles cert_req.pem
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

if [ $1 == "add_client" ]; then
	CLIENTS="${CLIENTS} $2"
	cat << EOS > ${OPENVPN_DIR}/.openvpn.env
FQDN="${FQDN}"
CLIENTS="${CLIENTS}"
EOS
	generate_client $2
else
	clean
	generate_rootCA
	generate_server
	generate_keys
	generate_clients
fi