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

## Server config

```bash
# Configure server.
cat << EOS > /etc/config/openvpn
config openvpn 'server'
	option keepalive '10 60'
	option verb '3'
	option ca '/etc/openvpn/demoCA/cacert.pem'
	option dh '/etc/openvpn/server/dh.pem'
	option cert '/etc/openvpn/server/server_cert.pem'
	option key '/etc/openvpn/server/server_key.pem'
	option tls_crypt '/etc/openvpn/server/tls_crypt.key'
	option dev 'tun0'
	option comp_lzo 'no'
	option auth 'SHA256'
	option cipher 'AES-256-GCM'
	option key_direction '0'
	option compress 'stub-v2'
	option topology 'subnet'
	option enabled '1'
	option server '172.18.254.0 255.255.255.0'
	option port '1194'
```
