# syntax = docker/dockerfile:1.4
FROM wordpress:php8.2-fpm

SHELL ["/bin/bash", "-e", "-c"]
ENV DEBIAN_FRONTEND noninteractive

RUN <<EOT
apt-get update
apt-get install -y \
  sendmail
apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false
rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /usr/share/doc/*

cp /usr/local/etc/php/php.ini-production /usr/local/etc/php/php.ini
EOT

COPY config/zz-docker.conf /usr/local/etc/php-fpm.d/
COPY config/wordpress.ini /usr/local/etc/php/conf.d/

ENTRYPOINT ["/entrypoint.sh"]
CMD ["php-fpm"]