# Setup

Create pass phrase
- `/etc/openvpn/root_ca_pass_phrase`

```bash
# Set env file
cat <<EOF > /etc/openvpn/.openvpn.env
FQDN="host"
CLIENTS="MacBookPro13 Pixel6Pro iPadPro11 Xperia10IV"
EOF
```

```bash
curl -o /etc/openvpn/openvpn.sh -L https://raw.githubusercontent.com/AkashiSN/Server-Config/main/docs/OpenWrt/scripts/openvpn.sh
chmod +x /etc/openvpn/openvpn.sh

/etc/openvpn/openvpn.sh

echo "/etc/openvpn/" >> /etc/sysupgrade.conf
```

## Add Client
```bash
/etc/openvpn/openvpn.sh add_client "client name"
```

## Server config

```bash
# Configure server.
cat << EOS > /etc/config/openvpn
config openvpn 'server_udp'
	option enabled '1'
	option dev 'tun0'
	option port '1194'
	option compress 'stub-v2'
	option dh '/etc/openvpn/server/dh.pem'
	option ca '/etc/openvpn/demoCA/cacert.pem'
	option cert '/etc/openvpn/server/server_cert.pem'
	option key '/etc/openvpn/server/server_key.pem'
	option tls_crypt '/etc/openvpn/server/tls_crypt.key'
	option auth 'SHA256'
	option cipher 'AES-256-GCM'
	option key_direction '0'
	option keepalive '10 60'
	option persist_tun '1'
	option persist_key '1'
	option user 'nobody'
	option group 'nogroup'
	option verb '5'
	option server '172.18.254.0 255.255.255.0'
	option topology 'subnet'
	list push 'dhcp-option DNS 172.16.254.110'
	list push 'route 172.16.0.0 255.255.255.0'
	list push 'route 172.16.10.0 255.255.255.0'
	list push 'route 172.16.100.0 255.255.255.0'
	list push 'route 172.16.254.0 255.255.255.0'
	list push 'block-ipv6'
	list push 'persist-tun'
	list push 'persist-key'
```
