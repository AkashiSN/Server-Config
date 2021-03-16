FROM nextcloud:fpm

ENV DEBIAN_FRONTEND noninteractive

RUN apt-get update && \
    apt-get install -y imagemagick libmagickwand-dev libsmbclient-dev smbclient iproute2 supervisor && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /usr/share/doc/* && \
    mkdir /var/log/supervisord /var/run/supervisord

RUN pecl install smbclient && \
    docker-php-ext-enable smbclient

COPY request-terminate-timeout.ini /usr/local/etc/php/conf.d/request-terminate-timeout.ini
COPY max-execution-time.ini /usr/local/etc/php/conf.d/max-execution-time.ini
COPY supervisord.conf /

ENV NEXTCLOUD_UPDATE=1

CMD ["/usr/bin/supervisord", "-c", "/supervisord.conf"]