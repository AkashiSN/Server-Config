# Setup

Create pass phrase
```bash
openssl rand -base64 32 > /etc/openvpn/root_ca_pass_phrase
```

```bash
# Set env file
cat <<EOF > /etc/openvpn/.openvpn.env
FQDN="host"
CLIENTS="MacBookPro13 iPhone15ProMax iPadPro11 Xperia10IV GlAxt1800"
EOF
```

```bash
# Download script
curl -o /etc/openvpn/openvpn.sh -L https://raw.githubusercontent.com/AkashiSN/Server-Config/main/docs/OpenWrt/scripts/openvpn.sh
chmod +x /etc/openvpn/openvpn.sh

# Init run script
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
	option dev 'tun0'
	option port '1194'
	option proto 'udp'
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
	option verb '3'
	option server '172.18.10.0 255.255.255.0'
	option topology 'subnet'
	list push 'dhcp-option DNS 172.16.254.110'
	list push 'route 172.16.0.0 255.255.255.0'
	list push 'route 172.16.10.0 255.255.255.0'
	list push 'route 172.16.100.0 255.255.255.0'
	list push 'route 172.16.254.0 255.255.255.0'
	list push 'block-ipv6'
	list push 'persist-tun'
	list push 'persist-key'
	option enabled '1'

config openvpn 'server_tcp'
	option dev 'tun1'
	option port '1194'
	option proto 'tcp-server'
	option tcp_queue_limit '256'
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
	option verb '3'
	option server '172.19.10.0 255.255.255.0'
	option topology 'subnet'
	list push 'dhcp-option DNS 172.16.254.110'
	list push 'route 172.16.0.0 255.255.255.0'
	list push 'route 172.16.10.0 255.255.255.0'
	list push 'route 172.16.100.0 255.255.255.0'
	list push 'route 172.16.254.0 255.255.255.0'
	list push 'block-ipv6'
	list push 'persist-tun'
	list push 'persist-key'
	option enabled '1'
```
