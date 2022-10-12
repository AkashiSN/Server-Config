# Setup

Create pass phrase
- `/etc/openvpn/root_ca_pass_phrase`

```bash
# Set env file
cat <<EOF > /etc/openvpn/.openvpn.env
FQDN="host"
CLIENTS="MacBookPro13 Pixel6Pro"
EOF
```

```bash
curl -o /etc/openvpn/openvpn.sh -L https://raw.githubusercontent.com/AkashiSN/Server-Config/main/docs/OpenWrt/scripts/openvpn.sh
chmod +x /etc/openvpn/openvpn.sh

/etc/openvpn/openvpn.sh
```

## Add Client
```bash
/etc/openvpn/openvpn.sh add_client "client name"
```

## Client config

```bash
source /etc/openvpn/.openvpn.env

LENGTH=`echo ${CLIENTS} | tr ' ' '\n' | wc -l`
for i in `seq ${LENGTH}`
do
  CLIENT=`echo ${CLIENTS} | cut -d ' ' -f $i`

  cat << EOS > /etc/openvpn/client/${CLIENT}.ovpn
client
nobind
dev tun
remote-cert-tls server
remote ${FQDN} 1194 udp
redirect-gateway def1

auth SHA256
cipher AES-256-GCM
key-direction 1

<key>
$(cat /etc/openvpn/client/${CLIENT}_key.pem)
</key>
<cert>
$(openssl x509 -in /etc/openvpn/client/${CLIENT}_cert.pem)
</cert>
<ca>
$(openssl x509 -in /etc/openvpn/server/ca_cert.pem)
</ca>
<tls-crypt>
$(cat /etc/openvpn/server/tls_crypt.key)
</tls-crypt>
EOS
done
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
