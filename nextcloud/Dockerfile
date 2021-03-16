FROM nextcloud:fpm

ENV DEBIAN_FRONTEND noninteractive

RUN apt-get update && \
    apt-get install -y imagemagick libmagickwand-dev libsmbclient-dev smbclient iproute2 && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /usr/share/doc/*

RUN pecl install smbclient && \
    docker-php-ext-enable smbclient

COPY memory-limit.ini /usr/local/etc/php/conf.d/memory-limit.ini
COPY upload-max-filesize.ini /usr/local/etc/php/conf.d/upload-max-filesize.ini
COPY max-execution-time.ini /usr/local/etc/php/conf.d/max-execution-time.ini