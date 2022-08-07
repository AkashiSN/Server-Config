# MinIO docker

## Setup disk

6TB HDDs are recognized from `/dev/sda` to `/dev/sdd`.
Format it with xfs, and then labeled `xfs1`, `xfs2`... respectively and mounted them in `/mnt/xfs1{1..4}`.

```bash
sudo parted /dev/sda --script 'mklabel gpt mkpart xfs1 xfs 2048s 11721045134s print quit'
sudo parted /dev/sdb --script 'mklabel gpt mkpart xfs2 xfs 2048s 11721045134s print quit'
sudo parted /dev/sdc --script 'mklabel gpt mkpart xfs3 xfs 2048s 11721045134s print quit'
sudo parted /dev/sdd --script 'mklabel gpt mkpart xfs4 xfs 2048s 11721045134s print quit'

sudo mkfs.xfs /dev/sda1 -f
sudo mkfs.xfs /dev/sdb1 -f
sudo mkfs.xfs /dev/sdc1 -f
sudo mkfs.xfs /dev/sdd1 -f

sudo mkdir /mnt/xfs{1..4}
sudo chown -R ${USER}:${USER} /mnt/*

echo "UUID=$(lsblk -no UUID /dev/sda1) /mnt/xfs1 xfs defaults 0 2" | sudo tee -a /etc/fstab
echo "UUID=$(lsblk -no UUID /dev/sdb1) /mnt/xfs2 xfs defaults 0 2" | sudo tee -a /etc/fstab
echo "UUID=$(lsblk -no UUID /dev/sdc1) /mnt/xfs3 xfs defaults 0 2" | sudo tee -a /etc/fstab
echo "UUID=$(lsblk -no UUID /dev/sdd1) /mnt/xfs4 xfs defaults 0 2" | sudo tee -a /etc/fstab
```

## Let's Encrypt

```bash
sudo snap install core
sudo snap refresh core

sudo snap install --classic certbot
sudo snap set certbot trust-plugin-with-root=ok
sudo ln -s /snap/bin/certbot /usr/bin/certbot
sudo snap install certbot-dns-cloudflare
sudo snap connect certbot:plugin certbot-dns-cloudflare

sudo -i

unset HISTFILE

export EMAIL=
export DOMAIN=
export CLOUDFLARE_API_TOKEN=

mkdir -p /root/.secrets/certbot/

cat << EOS > /root/.secrets/certbot/cloudflare.ini
dns_cloudflare_api_token = ${CLOUDFLARE_API_TOKEN}
EOS

chmod 640 /root/.secrets/certbot/cloudflare.ini

certbot certonly --dns-cloudflare --dns-cloudflare-credentials /root/.secrets/certbot/cloudflare.ini --dns-cloudflare-propagation-seconds 60 --server https://acme-v02.api.letsencrypt.org/directory -d ${DOMAIN} -d console.${DOMAIN} -m ${EMAIL}

cat <<\EOF | tee /etc/letsencrypt/renewal-hooks/deploy/nginx-reload.sh
#!/bin/sh

NGINX_CONTAINER_ID=$(docker ps --filter name=minio-nginx --format {{.ID}})
if [[ -n ${NGINX_CONTAINER_ID} ]]; then
	docker exec minio-nginx-1 nginx -s reload
fi
EOF

exit
```

## MinIO Client

```bash
sudo curl -L https://dl.min.io/client/mc/release/linux-amd64/mc -o /usr/local/bin/mc
sudo chmod +x /usr/local/bin/mc

mc alias set myminio https://DOMAIN
```