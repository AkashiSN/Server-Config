#!/bin/bash
set -eu

#
# Enable docker and docker-compose on TrueNAS SCALE (no Kubernetes)
#
# This script is a hack! Use it at your own risk!!
# Using this script to enable Docker is NOT SUPPORTED by ix-systems!
# You CANNOT use SCALE Apps while using this script!
#
# 1  Create a dedicated Docker dataset in one of your zpools
# 2  Save this script somewhere else on your zpool, not in the Docker dataset
# 3  Edit line 19 of the script, set a path to the Docker dataset you created
# 4  You can now start Docker by running the script from the SCALE console
#
#   Schedule this script to run via System Settings -> Advanced -> Init/Shutdown Scripts
#   Click Add -> Type: Script and choose this script -> When: choose to run as Post Init

if [ "$(id -u)" != "0" ]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi

echo "This script is running as root."

## set a path to your docker dataset
docker_dataset='/mnt/ssd/docker'

for file in /bin/apt*; do
  if [ ! -x "$file" ]; then
    echo " $file not executable, fixing..."
    chmod +x "$file"
  else
    echo "$file is already executable"
  fi
done

echo "All files in /bin/apt* are executable"

apt-get update

echo "Install docker dependency"
apt-get install -y ca-certificates curl gnupg lsb-release

mkdir -m 0755 -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --batch --yes --dearmor -o /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list
if [ ! -f /etc/docker.env ]; then
  touch /etc/docker.env
fi

echo "Install latest docker"
apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

## set the Docker storage-driver
version="$(cut -c 1-5 </etc/version | tr -d .)"

if ! [[ "${version}" =~ ^[0-9]+$ ]]; then
  echo "version is not an integer: ${version}"
  exit 1
elif [ "${version}" -le 2204 ]; then
  storage_driver='zfs'
elif [ "${version}" -ge 2212 ]; then
  storage_driver='overlay2'
fi

## HEREDOC: docker/daemon.json
read -r -d '' JSON <<END_JSON
{
  "data-root": "${docker_dataset}",
  "storage-driver": "${storage_driver}",
  "bip": "172.20.0.254/24",
  "exec-opts": [
    "native.cgroupdriver=cgroupfs"
  ]
}
END_JSON

## path to docker daemon file
docker_daemon='/etc/docker/daemon.json'

if [ "$(systemctl is-enabled k3s)" == "enabled" ]; then
  echo "You can not use this script while k3s is enabled"
  exit 1
fi

if [ "$(systemctl is-active k3s)" == "active" ]; then
  echo "You can not use this script while k3s is active"
  exit 1
fi

if ! zfs list "${docker_dataset}" &>/dev/null; then
  echo "Dataset not found: ${docker_dataset}"
else
  echo "Checking file: ${docker_daemon}"
  if test "${JSON}" != "$(cat ${docker_daemon} 2>/dev/null)"; then
    echo "Updating file: ${docker_daemon}"
    jq -n "${JSON}" >${docker_daemon}
    if [ "$(systemctl is-active docker)" == "active" ]; then
      echo "Restarting Docker"
      systemctl restart docker
    elif [ "$(systemctl is-enabled docker)" != "enabled" ]; then
      echo "Enable and starting Docker"
      systemctl enable --now docker
    fi
  fi
fi