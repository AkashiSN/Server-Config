# Server-Config

## 前提
SSH keyでログインできる状態

## 環境構築
### Common
```bash
# Update the apt package index
sudo apt update
# Upgrade outdated packages
sudo apt upgrade -y
# Install git, wget, curl, gettext
sudo apt install -y git wget curl gettext
```

### Zsh, Vim
```bash
# Install dependencies
sudo apt install -y gawk

# Install zsh
sudo apt install -y zsh vim

# Download .zshrc
wget -O $HOME/.zshrc https://gist.github.com/AkashiSN/4ff2eb541742bedb3d281725b6d15c3f/raw/zshrc

# Download .vimrc
wget -O $HOME/.vimrc https://gist.github.com/AkashiSN/4ff2eb541742bedb3d281725b6d15c3f/raw/vimrc

# Install zplug
curl -sL --proto-redir -all,https https://raw.githubusercontent.com/zplug/installer/master/installer.zsh | zsh

# Change default login shell
user=$(whoami)
sudo chsh -s $(which zsh) $user
```

### Docker

```bash
# Install the prerequisites:
sudo apt install -y \
    apt-transport-https \
    ca-certificates \
    gnupg-agent \
    software-properties-common

# Add Docker’s official GPG key
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -

# Set up the stable repository
sudo add-apt-repository \
   "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
   $(lsb_release -cs) \
   stable"

# Update the apt package index
sudo apt update

# Install the latest version of Docker Engine and containerd
sudo apt install -y docker-ce docker-ce-cli containerd.io

# Download docker compose
sudo curl -L "https://github.com/docker/compose/releases/download/1.27.4/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose

# Apply executable permissions to the binary:
sudo chmod +x /usr/local/bin/docker-compose

# Create a symbolic link to /usr/bin
sudo ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose
```

### Nginx
```bash
# Set up the mailline repository
sudo add-apt-repository \
    "deb [arch=amd64] https://nginx.org/packages/mainline/ubuntu \
    $(lsb_release -cs) \
    nginx"

# Add Nginx's official GPG key
curl -fsSL https://nginx.org/keys/nginx_signing.key | sudo apt-key add -

# Update the apt package index
sudo apt update

# Install the latest version of Nginx
sudo apt install nginx

# Set HostName to environment variable
export HOST_NAME=

# Copy setting file
envsubst '$$HOST_NAME' < tv.conf.template > /etc/nginx/conf.d/tv.conf
```

### Let's Encrypt

```bash
# Set up the certbot repository
sudo add-apt-repository ppa:certbot/certbot

# Update the apt package index
sudo apt update

# Install the latest version of certbot and cloudflare extention
sudo apt install -y certbot
sudo apt install -y python3-certbot-dns-cloudflare

# Set Email and domain to environment variable
export EMAIL=
export DOMAIN=
export CLOUDFLARE_API=

# Create cloudflare setting file
cat << EOS > sudo tee /etc/letsencrypt/cloudflare.ini
dns_cloudflare_email = ${EMAIL}
dns_cloudflare_api_key = ${CLOUDFLARE_API}
EOS

# Obtain ssl certificate
sudo certbot certonly --dns-cloudflare --dns-cloudflare-credentials /etc/letsencrypt/cloudflare.ini --dns-cloudflare-propagation-seconds 60 --server https://acme-v02.api.letsencrypt.org/directory -d ${DOMAIN} -d "*.${DOMAIN}" -m ${EMAIL}

# Reload nginx when certificate is renewed
echo "ExecStartPost=/bin/systemctl reload nginx" | sudo tee /lib/systemd/system/certbot.service
```

### DD Max m4 driver
https://note.spage.jp/archives/712
```bash
# Install the prerequisites:
sudo apt install -y dkms build-essential unzip

# Create work directory
mkdir ~/work
cd ~/work

# Download dddvb source
wget https://github.com/DigitalDevices/dddvb/archive/0.9.37.zip
unzip 0.9.37.zip
cd dddvb-0.9.37

# Make once
make

# Generate dkms.conf
cat <<'EOF' | tee dkms.conf
PACKAGE_NAME=dddvb
PACKAGE_VERSION=0.9.37
AUTOINSTALL="yes"
CHECK_MODULE_VERSION="no"
MAKE="'make' all KVER=${kernelver}"
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
sudo cp -r dddvb-0.9.37 /usr/src/

# Registration to DKMS
sudo dkms add -m dddvb -v 0.9.37

# Install present kernel driver
sudo dkms install -m dddvb -v 0.9.37

# Check DKMS status
dkms status

# Set up to use your own driver instead of the OS standard one.
sudo mkdir -p /etc/depmod.d
echo 'search extra updates built-in' | sudo tee /etc/depmod.d/extra.conf
sudo depmod -a
```

### SSLH
```bash
# Install the prerequisites:
sudo apt install -y libwrap0-dev libconfig8-dev libsystemd-dev libcap-dev libbsd-dev

# cd work directory
cd ~/work

# Download sslh source
wget https://github.com/yrutschle/sslh/archive/v1.21c.tar.gz
tar xvf v1.21c.tar.gz
cd sslh-1.21c

# Run make and install
make USELIBWRAP=1 USELIBCAP=1 USESYSTEMD=1 USELIBBSD=1
sudo make install

# Copy config file
cp basic.cfg /etc/sslh.cfg
cp scripts/systemd.sslh.service /etc/systemd/system/sslh.service
```

### OpenVPN
```bash
# Add OpenVPN's official GPG key
curl -s https://swupdate.openvpn.net/repos/repo-public.gpg | sudo apt-key add

# Set up the stable repository
sudo add-apt-repository \
    "deb [arch=amd64] https://build.openvpn.net/debian/openvpn/stable \
    $(lsb_release -cs) \
    main"
    
# Update the apt package index
sudo apt update

# Install the latest version of OpenVPN
sudo apt install -y openvpn
```
### OpenSSL
https://help.ui.com/hc/en-us/articles/115015971688-EdgeRouter-OpenVPN-Server
```bash
# Install OpenSSL
sudo apt install -y openssl

# Become root user
sudo su

# cd openssl dir
cd /usr/lib/ssl/misc

# Generate a Diffie-Hellman (DH) key
openssl dhparam -out ./dh.pem -2 4096

# Generate a root certificate
./CA.pl -newca

# Copy the newly created certificate + key to the OpenVPN directory
cp demoCA/cacert.pem /config/auth
cp demoCA/private/cakey.pem /config/auth

# Generate the server certificate
./CA.pl -newreq

# Sign the server certificate
./CA.pl -sign

# Move and rename the server certificate and key files to the OpenVPN directory
mv newcert.pem /config/auth/server.pem
mv newkey.pem /config/auth/server.key

# Generate, sign and move the certificate and key files for the first OpenVPN client
./CA.pl -newreq
./CA.pl -sign
mv newcert.pem /config/auth/client1.pem
mv newkey.pem /config/auth/client1.key

# Remove the password from the server key file and optionally the client key file(s)
openssl rsa -in /config/auth/server.key -out /config/auth/server-no-pass.key
openssl rsa -in /config/auth/client1.key -out /config/auth/client1-no-pass.key
openssl rsa -in /config/auth/client2.key -out /config/auth/client2-no-pass.key

# Overwrite the existing keys with the no-pass versions
mv /config/auth/server-no-pass.key /config/auth/server.key 
mv /config/auth/client1-no-pass.key /config/auth/client1.key 
mv /config/auth/client2-no-pass.key /config/auth/client2.key 

# Add read permission for non-root users to the client key files
chmod 644 /config/auth/client1.key
chmod 644 /config/auth/client2.key
```
