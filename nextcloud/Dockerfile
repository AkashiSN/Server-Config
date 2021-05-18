FROM nextcloud:fpm

ENV DEBIAN_FRONTEND noninteractive

RUN apt-get update && \
    apt-get install -y imagemagick libmagickwand-dev libsmbclient-dev smbclient iproute2 supervisor && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /usr/share/doc/*

RUN pecl install smbclient && \
    docker-php-ext-enable smbclient

RUN sed -i -e 's?access.log = /proc/self/fd/2?access.log = /proc/self/fd/1?' /usr/local/etc/php-fpm.d/docker.conf

COPY request-terminate-timeout.ini /usr/local/etc/php/conf.d/request-terminate-timeout.ini
COPY max-execution-time.ini /usr/local/etc/php/conf.d/max-execution-time.ini
COPY supervisord.conf /etc/

ENV NEXTCLOUD_UPDATE=1
