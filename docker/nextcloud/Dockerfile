# syntax = docker/dockerfile:1.4
FROM nextcloud:28.0.2-fpm

SHELL ["/bin/bash", "-e", "-c"]
ENV DEBIAN_FRONTEND noninteractive \
    NEXTCLOUD_UPDATE 1

RUN <<EOT
apt-get update
apt-get install -y \
  imagemagick \
  iproute2 \
  locales \
  libbz2-dev \
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
EOT

ENV LANG en_US.UTF-8 \
    LANGUAGE en_US:en \
    LC_ALL en_US.UTF-8

ENTRYPOINT ["/entrypoint.sh"]
CMD ["php-fpm"]
