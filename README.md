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

### Nvidia driver
```bash
# Download setting file
wget https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2004/x86_64/cuda-ubuntu2004.pin
sudo mv cuda-ubuntu2004.pin /etc/apt/preferences.d/cuda-repository-pin-600

# Add nvidia's official GPG key
sudo apt-key adv --fetch-keys https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2004/x86_64/7fa2af80.pub

# Set up the stable repository
sudo add-apt-repository "deb https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2004/x86_64/ /"

# Update the apt package index
sudo apt update

# Install the latest version of Nvidia driver
sudo apt -y install cuda-drivers
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

# Add nvidia-docker repository
distribution=$(. /etc/os-release;echo $ID$VERSION_ID) \
   && curl -s -L https://nvidia.github.io/nvidia-docker/gpgkey | sudo apt-key add - \
   && curl -s -L https://nvidia.github.io/nvidia-docker/$distribution/nvidia-docker.list | sudo tee /etc/apt/sources.list.d/nvidia-docker.list

# Update the apt package index
sudo apt update

# Install the latest version of nvidia-docker2
sudo apt install -y nvidia-docker2

# Restart the Docker daemon
sudo systemctl restart docker
```

### Let's Encrypt

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
export CLOUDFLARE_API=

# Create secret directory
mkdir -p /root/.secrets/certbot/

# Create cloudflare setting file
cat << EOS > /root/.secrets/certbot/cloudflare.ini
dns_cloudflare_email = ${EMAIL}
dns_cloudflare_api_key = ${CLOUDFLARE_API}
EOS

# Change permission
chmod 640 /root/.secrets/certbot/cloudflare.ini

# Obtain ssl certificate
certbot certonly --dns-cloudflare --dns-cloudflare-credentials /root/.secrets/certbot/cloudflare.ini --dns-cloudflare-propagation-seconds 60 --server https://acme-v02.api.letsencrypt.org/directory -d ${DOMAIN} -d "*.${DOMAIN}" -m ${EMAIL}

# Exit root
exit
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

# restart
sudo reboot
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
