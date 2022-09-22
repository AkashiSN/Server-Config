# Setup

## Docker
```bash
# Add Docker’s official GPG key
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

# Set up the stable repository
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list

# Update the apt package index
sudo apt update

# Install the latest version of Docker Engine and containerd
sudo apt install -y docker-ce docker-ce-cli containerd.io

# Create plugin dir
sudo mkdir -p /usr/local/lib/docker/cli-plugins
```

## Docker Compose

```bash
# Download docker compose
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/lib/docker/cli-plugins/docker-compose

# Apply executable permissions to the binary:
sudo chmod +x /usr/local/lib/docker/cli-plugins/docker-compose
```

## Let's Encrypt

```bash
# Ensure that your version of snapd is up to date
sudo snap install core
sudo snap refresh core

# Install certbot with classic mode
sudo snap install --classic certbot

# Confirm plugin containment level
sudo snap set certbot trust-plugin-with-root=ok

# Prepare the Certbot command
sudo ln -s /snap/bin/certbot /usr/bin/certbot

# Install certbot cloudflare addon
sudo snap install certbot-dns-cloudflare

# Connect with plugin
sudo snap connect certbot:plugin certbot-dns-cloudflare

# Become root
sudo -i

# Do not write histroyfile
unset HISTFILE

# Set Email and domain to environment variable
export EMAIL=
export DOMAIN=
export TV_SUBDOMAIN=
export CLOUDFLARE_API_TOKEN=

# Create secret directory
mkdir -p /root/.secrets/certbot/

# Create cloudflare setting file
cat << EOS > /root/.secrets/certbot/cloudflare.ini
dns_cloudflare_api_token = ${CLOUDFLARE_API_TOKEN}
EOS

# Change permission
chmod 640 /root/.secrets/certbot/cloudflare.ini

# Obtain ssl certificate
certbot certonly --dns-cloudflare --dns-cloudflare-credentials /root/.secrets/certbot/cloudflare.ini --dns-cloudflare-propagation-seconds 60 --server https://acme-v02.api.letsencrypt.org/directory -d ${DOMAIN} -d ${TV_SUBDOMAIN}.${DOMAIN} -d ${TV_SUBDOMAIN}-local.${DOMAIN} -m ${EMAIL}

# Nginx reload script
cat <<\EOF | tee /etc/letsencrypt/renewal-hooks/deploy/nginx-reload.sh
#!/bin/sh

NGINX_CONTAINER_ID=$(docker ps --filter name=compose-nginx --format {{.ID}})
if [[ -n ${NGINX_CONTAINER_ID} ]]; then
	docker exec compose-nginx-1 nginx -s reload
fi
EOF

# Exit root
exit
```

## Cloudflared

```bash
# Download cloudflared
curl -s https://api.github.com/repos/cloudflare/cloudflared/releases/latest | grep -E 'browser_download_url' | grep linux-amd64 | grep -v 'fips' | grep -v 'deb' | cut -d '"' -f 4 | xargs -n1 sudo curl -L -o /usr/local/bin/cloudflared

# Apply executable permissions to the binary:
sudo chmod +x /usr/local/bin/cloudflared
```

## Cloudflare Argo Tunnel

```bash
# Become root
sudo -i

# Authorize cloudflared
cloudflared tunnel login

export TV_SUBDOMAIN=
export DOMAIN=

# Create tunnel
cloudflared tunnel create -o yaml ${TV_SUBDOMAIN}

# Get tunnel id
TUNNEL_ID=$(cloudflared tunnel info tv | cut -d " " -f 3)

# add etc hosts
echo "127.0.0.1 ${TV_SUBDOMAIN}.${DOMAIN}" >> /etc/hosts

# Set up dns for tunnel
cloudflared tunnel route dns ${TV_SUBDOMAIN} ${TV_SUBDOMAIN}.${DOMAIN}

# Create config file
cat << EOS > /root/.cloudflared/config.yaml
url: https://${TV_SUBDOMAIN}.${DOMAIN}
tunnel: ${TUNNEL_ID}
credentials-file: /root/.cloudflared/${TUNNEL_ID}.json
EOS

# Install cloudflared as service
cloudflared service install

# Run on boot
systemctl enable cloudflared

# Exit root
exit
```

### DKMS Setting

```bash
# Install the prerequisites:
sudo apt install -y dkms build-essential unzip

# Set up to use your own driver instead of the OS standard one.
sudo mkdir -p /etc/depmod.d
echo 'search extra updates built-in' | sudo tee /etc/depmod.d/extra.conf
sudo depmod -a

# reboot
sudo reboot
```

### DD Max m4 driver
Many thanks : https://note.spage.jp/archives/712

```bash
DDDVB_VERSION=0.9.37

# Download dddvb source
wget https://github.com/DigitalDevices/dddvb/archive/${DDDVB_VERSION}.zip
unzip ${DDDVB_VERSION}.zip
cd dddvb-${DDDVB_VERSION}

# Make once
make

# Generate dkms.conf
cat <<EOF | tee dkms.conf
PACKAGE_NAME=dddvb
PACKAGE_VERSION=${DDDVB_VERSION}
AUTOINSTALL="yes"
CHECK_MODULE_VERSION="no"
MAKE="'make' all KVER=\${kernelver}"
CLEAN="make clean"
EOF

let "module_number=0" || true
for file in $(find ./ -type f -name "*.ko"); do
      MODULE_LOCATION=$(dirname $file | cut -d\/ -f 2-)
      echo "BUILT_MODULE_NAME[$module_number]=\"$(basename $file .ko)\"" >> dkms.conf
      echo "BUILT_MODULE_LOCATION[$module_number]=\"$MODULE_LOCATION\"" >> dkms.conf
      echo "DEST_MODULE_LOCATION[$module_number]=\"/extramodules/$pkgname\"" >> dkms.conf
      let "module_number=${module_number}+1" || true
done

# Rememove check module
make clean

# Update Makefile
sed -i -e 's/shell uname -r/KVER/g' Makefile

# Copy sorce to dkms dir
cd ..
sudo mv dddvb-${DDDVB_VERSION} /usr/src/

sudo dkms add -m dddvb -v ${DDDVB_VERSION}
sudo dkms build -m dddvb -v ${DDDVB_VERSION}
sudo dkms install -m dddvb -v ${DDDVB_VERSION}
dkms status
```

## Network

```bash
./setup-network.sh
```

# Run

```bash
docker compose up -d
```