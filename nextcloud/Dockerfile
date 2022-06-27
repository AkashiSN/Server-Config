# syntax=docker.io/docker/dockerfile:1.4.2-labs

FROM nextcloud:24.0.2-fpm

SHELL ["/bin/bash", "-e", "-c"]
ENV DEBIAN_FRONTEND noninteractive

COPY ./supervisord.conf /etc/
COPY ./*.sh /usr/local/bin/

RUN <<EOT
apt-get update
apt-get install -y \
  default-mysql-client \
  imagemagick \
  iproute2 \
  jq \
  libmagickwand-dev \
  libsmbclient-dev \
  smbclient \
  supervisor
apt-get clean
rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /usr/share/doc/*

pecl install smbclient
docker-php-ext-enable smbclient

echo '0 4 * * *  /bin/bash /usr/local/bin/backup.sh' >> /var/spool/cron/crontabs/www-data

cp /usr/local/etc/php/php.ini-production /usr/local/etc/php/php.ini

cat << EOF > /usr/local/etc/php-fpm.d/zz-docker.conf
[global]
daemonize = no

[www]
user  = www-data
group = www-data

listen = /var/run/socket/php-fpm.sock
listen.owner = www-data
listen.group = www-data
listen.mode  = 0660

access.log = /proc/self/fd/1

pm.max_children      = 163
pm.start_servers     = 40
pm.min_spare_servers = 40
pm.max_spare_servers = 122
EOF

cat << EOF > /usr/local/etc/php/conf.d/nextcloud.ini
memory_limit = 30G

upload_max_filesize=1000M
upload_tmp_dir=/tmp/upload
post_max_size=2000M

request_terminate_timeout=86400
max_execution_time=86400
output_buffering=0
EOF

mkdir -p /tmp/upload
chown www-data:www-data -R /tmp/upload
chmod +x /usr/local/bin/*.sh
EOT

ENV NEXTCLOUD_UPDATE=1
