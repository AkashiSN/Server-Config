FROM nextcloud

ENV DEBIAN_FRONTEND noninteractive

RUN apt-get update && \
    apt-get install -y libsmbclient-dev smbclient && \
    pecl install smbclient && \
    docker-php-ext-enable smbclient
