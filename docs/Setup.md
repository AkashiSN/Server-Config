## 環境構築

- Ubuntu 20.04

### Common
```bash
# Update the apt package index
sudo apt update
# Upgrade outdated packages
sudo apt upgrade -y
# Install git, wget, curl
sudo apt install -y git wget curl
```

### Timezone

```bash
# Set timezone to Asia/Tokyo
timedatectl set-timezone Asia/Tokyo
```

### Zsh, Vim
```bash
# Install zsh, vim
sudo apt install -y zsh vim

# Install dotfiles and sometools.
zsh <(curl -L https://raw.githubusercontent.com/AkashiSN/dotfiles/main/setup.zsh)
```

### ZFS
```bash
$ sudo apt install -y zfsutils-linux
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

# restart
sudo reboot
```

### MicroK8s

```bash
# Install microk8s with snap
sudo snap install microk8s --classic

# Turn on the dns storage services
sudo microk8s enable dns storage

# Set alias
sudo snap alias microk8s.kubectl mk
```

### kubectl

```bash
# Download latest kubectl
sudo curl -L "https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl" -o /usr/local/bin/kubectl

# Apply executable permissions to the binary
sudo chmod +x /usr/local/bin/kubectl
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
```

#### Docker Compose

```bash
# Download docker compose
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose

# Apply executable permissions to the binary:
sudo chmod +x /usr/local/bin/docker-compose

# Create a symbolic link to /usr/bin
sudo ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose
```

#### Buildkit

```bash
# Download buildkit
curl -s https://api.github.com/repos/moby/buildkit/releases/latest | grep -E 'browser_download_url' | grep linux-amd64 | cut -d '"' -f 4 | wget -O /tmp/buildkit-linux-amd64.tar.gz -i -
sudo tar xvf /tmp/buildkit-linux-amd64.tar.gz -C /usr/local/
```

#### Nvidia docker

```bash
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

### Cloudflared

```bash
# Download cloudflared
curl -s https://api.github.com/repos/cloudflare/cloudflared/releases/latest | grep -E 'browser_download_url' | grep linux-amd64 | cut -d '"' -f 4 | xargs -n1 sudo curl -L -o /usr/local/bin/cloudflared

# Apply executable permissions to the binary:
sudo chmod +x /usr/local/bin/cloudflared
```

## Cloudflare Argo Tunnelの設定

```bash
# Become root
sudo -i

# Authorize cloudflared
cloudflared tunnel login

export TV_SUBDOMAIN=
export DOMAIN=

# Create tunnel
TUNNEL_ID=$(cloudflared tunnel create -o yaml ${TV_SUBDOMAIN} | grep id | cut -d " " -f 2)

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
systemctl enable cloudflared.service
```

### DD Max m4 driver
Many thanks : https://note.spage.jp/archives/712

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

### Serve setting
自動で休止モードにならないようにする

Ref : https://askubuntu.com/questions/47311/how-do-i-disable-my-system-from-going-to-sleep

```bash
sudo systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target
```
