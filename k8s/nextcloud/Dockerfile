# syntax=docker.io/docker/dockerfile:1.4.2-labs

FROM nextcloud:24.0.5-fpm

SHELL ["/bin/bash", "-e", "-c"]
ENV DEBIAN_FRONTEND noninteractive

RUN <<EOT
apt-get update
apt-get install -y \
  imagemagick \
  iproute2 \
  jq \
  libbz2-dev \
  libmagickwand-dev \
  libsmbclient-dev \
  smbclient
apt-get clean
rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /usr/share/doc/*

pecl install smbclient
docker-php-ext-enable smbclient
docker-php-ext-install bz2

rm -r /tmp/pear

cp /usr/local/etc/php/php.ini-production /usr/local/etc/php/php.ini

cat << 'EOF' > /usr/local/etc/php-fpm.d/zz-docker.conf
[global]
daemonize = no

[www]
user  = www-data
group = www-data

listen = 0.0.0.0:9000
listen.owner = www-data
listen.group = www-data

access.format = "%{REMOTE_ADDR}e - %u %t \"%m %{REQUEST_URI}e\" %s"

access.log = /proc/self/fd/1

pm.max_children      = 163
pm.start_servers     = 40
pm.min_spare_servers = 40
pm.max_spare_servers = 122
EOF

cat << 'EOF' > /usr/local/etc/php/conf.d/nextcloud.ini
memory_limit = 30G

upload_max_filesize=2000M
post_max_size=2000M

request_terminate_timeout=86400
max_execution_time=86400
output_buffering=0
EOF

cat << 'EOF' > /init.sh
#!/bin/sh
set -eu

chmod 0770 ${NEXTCLOUD_DATA_DIR}

exec "$@"
EOF

chmod +x /init.sh

cat << 'EOF' > /custom-entrypoint.sh
#!/bin/sh
set -eu

run_as() {
    if [ "$(id -u)" = 0 ]; then
        su -p www-data -s /bin/sh -c "$1"
    else
        sh -c "$1"
    fi
}

run_as 'php /var/www/html/occ app:enable files_external'
run_as 'php /var/www/html/occ app:enable twofactor_totp'

run_as 'php /var/www/html/occ config:system:set default_phone_region --value=JP'

exec "$@"
EOF

chmod +x /custom-entrypoint.sh
EOT

ENV NEXTCLOUD_UPDATE=1

ENTRYPOINT ["/init.sh", "/entrypoint.sh", "/custom-entrypoint.sh"]
CMD ["php-fpm"]