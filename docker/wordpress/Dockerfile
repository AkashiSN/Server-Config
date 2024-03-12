# syntax = docker/dockerfile:1.4
FROM wordpress:6.4.3-php8.2-fpm

SHELL ["/bin/bash", "-e", "-c"]
ENV DEBIAN_FRONTEND=noninteractive

RUN <<EOT
apt-get update
apt-get install -y \
  sendmail \
  less
apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false
rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /usr/share/doc/*

curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
chmod +x wp-cli.phar
mv wp-cli.phar /usr/local/bin/wp

pecl install redis
docker-php-ext-enable redis

cp /usr/local/etc/php/php.ini-production /usr/local/etc/php/php.ini
EOT

ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["php-fpm"]