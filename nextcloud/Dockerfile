FROM nextcloud:23.0.2-fpm

ENV DEBIAN_FRONTEND noninteractive

RUN apt-get update && \
    apt-get install -y imagemagick libmagickwand-dev libsmbclient-dev smbclient iproute2 supervisor default-mysql-client jq && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /usr/share/doc/* && \
    \
    pecl install smbclient && \
    docker-php-ext-enable smbclient && \
    \
    echo '0 4 * * *  /bin/bash /usr/local/bin/backup.sh' >> /var/spool/cron/crontabs/www-data  && \
    \
    sed -i -e 's?access.log = /proc/self/fd/2?access.log = /proc/self/fd/1?' /usr/local/etc/php-fpm.d/docker.conf && \
    sed -i -e 's?pm.max_children = 5?pm.max_children = 100?' /usr/local/etc/php-fpm.d/www.conf && \
    sed -i -e 's?listen = 127.0.0.1:9000?listen = /var/run/socket/php-fpm.sock?' /usr/local/etc/php-fpm.d/www.conf && \
    sed -i -e 's?;listen.owner = www-data?listen.owner = www-data?' /usr/local/etc/php-fpm.d/www.conf && \
    sed -i -e 's?;listen.group = www-data?listen.group = www-data?' /usr/local/etc/php-fpm.d/www.conf && \
    sed -i -e 's?;listen.mode = 0660?listen.mode = 0666?' /usr/local/etc/php-fpm.d/www.conf && \
    echo 'request_terminate_timeout=86400' > /usr/local/etc/php/conf.d/request-terminate-timeout.ini && \
    echo 'max_execution_time=86400' > /usr/local/etc/php/conf.d/max-execution-time.ini && \
    echo 'upload_tmp_dir=/tmp/upload' > /usr/local/etc/php/conf.d/upload-tmp-dir.ini && \
    echo 'output_buffering=0' >> /usr/local/etc/php/conf.d/upload-tmp-dir.ini && \
    echo '[global]' > /usr/local/etc/php-fpm.d/zz-docker.conf && \
    echo 'daemonize = no' >> /usr/local/etc/php-fpm.d/zz-docker.conf && \
    mkdir -p /tmp/upload && \
    chown www-data:www-data -R /tmp/upload

COPY supervisord.conf /etc/
COPY *.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/*.sh

ENV NEXTCLOUD_UPDATE=1
