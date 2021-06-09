FROM nextcloud:fpm

ENV DEBIAN_FRONTEND noninteractive

RUN apt-get update && \
    apt-get install -y imagemagick libmagickwand-dev libsmbclient-dev smbclient iproute2 supervisor default-mysql-client jq && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /usr/share/doc/* && \
    \
    pecl install smbclient && \
    docker-php-ext-enable smbclient && \
    \
    echo '0 4 * * *  /bin/bash /usr/local/bin/backup.sh' > /var/spool/cron/crontabs/www-data  && \
    \
    sed -i -e 's?access.log = /proc/self/fd/2?access.log = /proc/self/fd/1?' /usr/local/etc/php-fpm.d/docker.conf && \
    echo 'request_terminate_timeout=0' > /usr/local/etc/php/conf.d/request-terminate-timeout.ini && \
    echo 'max_execution_time=36000' > /usr/local/etc/php/conf.d/max-execution-time.ini

COPY supervisord.conf /etc/
COPY *.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/*.sh

ENV NEXTCLOUD_UPDATE=1
