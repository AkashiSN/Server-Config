# syntax = docker/dockerfile:1.4
FROM nextcloud:27.0.1-fpm

SHELL ["/bin/bash", "-e", "-c"]
ENV DEBIAN_FRONTEND noninteractive
ENV NEXTCLOUD_UPDATE=1

RUN <<EOT
apt-get update
apt-get install -y \
  imagemagick \
  iproute2 \
  locales \
  libbz2-dev \
  libmagickwand-dev \
  libsmbclient-dev \
  smbclient
apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false
rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /usr/share/doc/*

sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen
locale-gen

pecl install smbclient
docker-php-ext-enable smbclient
docker-php-ext-install bz2
rm -r /tmp/pear

cp /usr/local/etc/php/php.ini-production /usr/local/etc/php/php.ini

cat << 'EOF' | tee /docker-entrypoint-hooks.d/{pre-installation,pre-upgrade}/change_permissions.sh
#!/bin/bash
set -eu
chgrp www-data "${NEXTCLOUD_DATA_DIR}"
chmod 0770 "${NEXTCLOUD_DATA_DIR}"
EOF

chmod +x /docker-entrypoint-hooks.d/{pre-installation,pre-upgrade}/change_permissions.sh

cat << 'EOF' | tee /docker-entrypoint-hooks.d/before-starting/00change_permissions.sh
#!/bin/bash
set -e
# EXTERNAL_DIRS is of the form "dir1,dir2,dir3".
if [ -n "${EXTERNAL_DIRS}" ]; then
  IFS=',' read -r -a EXTERNAL_DIRS_LIST <<< "$EXTERNAL_DIRS"
  for dir in "${EXTERNAL_DIRS_LIST[@]}"; do
    chgrp www-data "${dir}"
    chmod 0770 "${dir}"
  done
fi
EOF

chmod +x /docker-entrypoint-hooks.d/before-starting/00change_permissions.sh
EOT

ENV LANG en_US.UTF-8 \
    LANGUAGE en_US:en \
    LC_ALL en_US.UTF-8

ADD https://raw.githubusercontent.com/AkashiSN/nextcloud-docker/master/docker-entrypoint.sh /docker-entrypoint.sh

COPY config/zz-docker.conf /usr/local/etc/php-fpm.d/
COPY config/nextcloud.ini /usr/local/etc/php/conf.d/

ENTRYPOINT ["/bin/sh", "/docker-entrypoint.sh"]
CMD ["php-fpm"]