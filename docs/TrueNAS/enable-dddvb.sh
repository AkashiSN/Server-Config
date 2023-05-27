#!/bin/bash
set -eu

if [ "$(id -u)" != "0" ]; then
  echo "This script must be run as root" 1>&2
  exit 1
fi

echo "This script is running as root."

for file in /bin/apt*; do
  if [ ! -x "$file" ]; then
    echo " $file not executable, fixing..."
    chmod +x "$file"
  else
    echo "$file is already executable"
  fi
done

echo "All files in /bin/apt* are executable"

echo "Update the apt package index"
apt-get update

echo "Install dddvb dependency"
apt-get install -y dkms build-essential unzip

mkdir -p /tmp/dddvb
cd /tmp/dddvb

echo "Download dddvb source"
DDDVB_VERSION="0.9.38"
wget https://github.com/DigitalDevices/dddvb/archive/${DDDVB_VERSION}.zip
unzip ${DDDVB_VERSION}.zip
cd dddvb-${DDDVB_VERSION}

echo "Make once"
make

echo "Generate dkms.conf"
cat <<EOF | tee dkms.conf
PACKAGE_NAME=dddvb
PACKAGE_VERSION=${DDDVB_VERSION}
AUTOINSTALL="yes"
CHECK_MODULE_VERSION="no"
MAKE="'make' all KVER=\${kernelver}"
CLEAN="make clean"
EOF

let "module_number=0" || true
pkgname="dddvb-dkms"
for file in $(find ./ -type f -name "*.ko"); do
  MODULE_LOCATION=$(dirname $file | cut -d\/ -f 2-)
  echo "BUILT_MODULE_NAME[$module_number]=\"$(basename $file .ko)\"" >> dkms.conf
  echo "BUILT_MODULE_LOCATION[$module_number]=\"$MODULE_LOCATION\"" >> dkms.conf
  echo "DEST_MODULE_LOCATION[$module_number]=\"/extramodules/$pkgname\"" >> dkms.conf
  let "module_number=${module_number}+1" || true
done

echo "Rememove check module"
make clean

echo "Update Makefile"
sed -i -e 's/shell uname -r/KVER/g' Makefile

echo "Copy sorce to dkms dir"
cd ..
cp -r dddvb-${DDDVB_VERSION} /usr/src/

echo Registration to DKMS
dkms add -m dddvb -v ${DDDVB_VERSION}

echo "Install present kernel driver"
dkms install -m dddvb -v ${DDDVB_VERSION}

echo "Check DKMS status"
dkms status

echo "Set up to use your own driver instead of the OS standard one."
mkdir -p /etc/depmod.d
echo 'search extra updates built-in' | tee /etc/depmod.d/extra.conf
depmod -a

echo "please restart apply driver."
# reboot