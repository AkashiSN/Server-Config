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

# Install the prerequisites:
sudo apt-get install -y \
   apt-transport-https \
   ca-certificates \
   curl \
   gnupg \
   lsb-release
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

### Bazel
```bash
# Add Bazel’s official GPG key
curl -fsSL https://bazel.build/bazel-release.pub.gpg | sudo gpg --dearmor -o /etc/apt/trusted.gpg.d/bazel.gpg

# Set up the stable repository
echo "deb [arch=amd64] https://storage.googleapis.com/bazel-apt stable jdk1.8" | sudo tee /etc/apt/sources.list.d/bazel.list

# Update the apt package index
sudo apt update

# Install the latest version of bazel
sudo apt install -y build-essential bazel

# Download buildtools
sudo curl -L $(curl -sL https://api.github.com/repos/bazelbuild/buildtools/releases | grep -E 'browser_download_url' | grep -E 'linux-amd64' | grep -E 'buildifier' | sort --version-sort | tail -1 | cut -d '"' -f 4) -o /usr/local/bin/buildifier

# Apply executable permissions to the binary:
sudo chmod +x /usr/local/bin/buildifier
```

### kind
```bash
# Download kind
sudo curl -L $(curl -sL https://api.github.com/repos/kubernetes-sigs/kind/releases | grep -E 'browser_download_url' | grep -E 'linux-amd64' | grep -v 'sum' | sort --version-sort | tail -1 | cut -d '"' -f 4) -o /usr/local/bin/kind

# Apply executable permissions to the binary:
sudo chmod +x /usr/local/bin/kind
```

### MicroK8s

```bash
# Install microk8s with snap
sudo snap install microk8s --classic

# Set alias
sudo snap alias microk8s.kubectl mk

# Create config dir
mkdir -p $HOME/.kube

# Add group to microk8s
sudo usermod -a -G microk8s ${USER}

# Turn on the dns services
microk8s enable dns

# Export config
microk8s.config > $HOME/.kube/microk8s-config

# Set default context
ln -s $HOME/.kube/microk8s-config $HOME/.kube/config
```

### kubectl

```bash
# Download kubectl
sudo curl -L "https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl" -o /usr/local/bin/kubectl

# Apply executable permissions to the binary
sudo chmod +x /usr/local/bin/kubectl
```

### krew
```bash
(
  set -x; cd "$(mktemp -d)" &&
  OS="$(uname | tr '[:upper:]' '[:lower:]')" &&
  ARCH="$(uname -m | sed -e 's/x86_64/amd64/' -e 's/\(arm\)\(64\)\?.*/\1\2/' -e 's/aarch64$/arm64/')" &&
  KREW="krew-${OS}_${ARCH}" &&
  curl -fsSLO "https://github.com/kubernetes-sigs/krew/releases/latest/download/${KREW}.tar.gz" &&
  tar zxvf "${KREW}.tar.gz" &&
  ./"${KREW}" install krew
)
```

### istioctl

```bash
# Download istio
curl -L https://istio.io/downloadIstio | sh -

# Move to opt
sudo mv istio-* /opt/istio

# Create symlink
sudo ln -s /opt/istio/bin/istioctl /usr/local/bin/istioctl
```

### skaffold
```bash
# Download skaffold
sudo curl -L https://storage.googleapis.com/skaffold/releases/latest/skaffold-linux-amd64 -o /usr/local/bin/skaffold

# Apply executable permissions to the binary
sudo chmod +x /usr/local/bin/skaffold
```

### Knative

```bash
# Enable load balancer
echo '192.168.100.1-192.168.100.254' | sudo microk8s enable metallb

# Install istio service
istioctl install

# Install knative service
KNATIVE_SERVICE_VERSION=$(curl -sL https://api.github.com/repos/knative/serving/releases | grep -E 'tag_name' | sort --version-sort | tail -1 | cut -d '"' -f 4)
kubectl apply -f https://github.com/knative/serving/releases/download/${KNATIVE_SERVICE_VERSION}/serving-crds.yaml
kubectl apply -f https://github.com/knative/serving/releases/download/${KNATIVE_SERVICE_VERSION}/serving-core.yaml

# Install istio for knative
KNATIVE_NET_ISTIO_VERSION=$(curl -sL https://api.github.com/repos/knative-sandbox/net-istio/releases | grep -E 'tag_name' | sort --version-sort | tail -1 | cut -d '"' -f 4)
kubectl apply -f https://github.com/knative-sandbox/net-istio/releases/download/${KNATIVE_NET_ISTIO_VERSION}/net-istio.yaml

# Setup Knative DOMAIN DNS
INGRESS_HOST=$(kubectl get svc -n istio-system istio-ingressgateway -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
KNATIVE_DOMAIN=${INGRESS_HOST}.sslip.io
kubectl patch configmap -n knative-serving config-domain -p "{\"data\": {\"${KNATIVE_DOMAIN}\": \"\"}}"

# Install knative eventing
KNATIVE_EVENTING_VERSION=$(curl -sL https://api.github.com/repos/knative/eventing/releases | grep -E 'tag_name' | sort --version-sort | tail -1 | cut -d '"' -f 4)
kubectl apply -f https://github.com/knative/eventing/releases/download/${KNATIVE_EVENTING_VERSION}/eventing-crds.yaml
kubectl apply -f https://github.com/knative/eventing/releases/download/${KNATIVE_EVENTING_VERSION}/eventing-core.yaml
kubectl apply -f https://github.com/knative/eventing/releases/download/${KNATIVE_EVENTING_VERSION}/in-memory-channel.yaml
kubectl apply -f https://github.com/knative/eventing/releases/download/${KNATIVE_EVENTING_VERSION}/mt-channel-broker.yaml

kubectl apply -f - <<EOF
apiVersion: eventing.knative.dev/v1
kind: broker
metadata:
 name: example-broker
 namespace: default
EOF
```

### Knative client

```bash
# Download latest kn
sudo curl -L $(curl -sL https://api.github.com/repos/knative/client/releases | grep -E 'browser_download_url' | grep -E 'linux-amd64' | sort --version-sort | tail -1 | cut -d '"' -f 4) -o /usr/local/bin/kn

# Apply executable permissions to the binary
sudo chmod +x /usr/local/bin/kn
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

### r8125 driver
Many thanks: https://qiita.com/hugashy/items/0150e10aea2cf9621ba8

Download from: https://www.realtek.com/en/component/zoo/category/network-interface-controllers-10-100-1000m-gigabit-ethernet-pci-express-software

```bash
R8125_VERSION="9.008.00"

tar xvf r8125-${R8125_VERSION}.tar.bz2
sudo mv r8125-${R8125_VERSION} /usr/src

# Update Makefile
sed -i -e 's/shell uname -r/KVER/g' /usr/src/r8125-${R8125_VERSION}/src/Makefile

# Generate dkms.conf
cat <<EOF | tee /usr/src/r8125-${R8125_VERSION}/dkms.conf
PACKAGE_NAME="r8125"
PACKAGE_VERSION="${R8125_VERSION}"
BUILT_MODULE_LOCATION[0]="src"
BUILT_MODULE_NAME[0]="r8125"
MAKE[0]="'make' KVER=\${kernelver} modules"
CLEAN="'make' clean KVER=\${kernelver}"
DEST_MODULE_LOCATION[0]="/updates/dkms"
AUTOINSTALL="yes"
EOF

sudo dkms add -m r8125 -v ${R8125_VERSION}
sudo dkms build -m r8125 -v ${R8125_VERSION}
sudo dkms install -m r8125 -v ${R8125_VERSION}
dkms status
```

### Serve setting
自動で休止モードにならないようにする

Ref : https://askubuntu.com/questions/47311/how-do-i-disable-my-system-from-going-to-sleep

```bash
sudo systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target
```


## NIC Offload setting

https://jisaba.life/2022/02/05/e1000e-0000001f-6-eno1-detected-hardware-unit-hang/

```bash
echo 'ACTION=="add", SUBSYSTEM=="net", KERNEL=="eno1", RUN+="/sbin/ethtool --offload eno1 gso off gro off tso off rx off tx off rxvlan off txvlan off sg off"' | sudo tee /etc/udev/rules.d/50-eth.rules
```