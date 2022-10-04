# syntax = docker/dockerfile:1.4
FROM nextcloud:24.0.5-fpm

SHELL ["/bin/bash", "-e", "-c"]
ENV DEBIAN_FRONTEND noninteractive
ENV NEXTCLOUD_UPDATE=1

COPY --chmod="+X" scripts/*.sh /

RUN <<EOT
apt-get update
apt-get install -y \
  imagemagick \
  iproute2 \
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

# Remove this patch when the release comes out.
cd /usr/src/nextcloud/
curl -O https://patch-diff.githubusercontent.com/raw/nextcloud/server/pull/34035.diff
patch -p1 < 34035.diff
EOT

COPY config/zz-docker.conf /usr/local/etc/php-fpm.d/
COPY config/nextcloud.ini /usr/local/etc/php/conf.d/

ENTRYPOINT ["/init.sh", "/entrypoint.sh", "/custom-entrypoint.sh"]
CMD ["php-fpm"]