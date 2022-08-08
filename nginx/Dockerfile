# syntax=docker.io/docker/dockerfile:1.4.2-labs

FROM nginx:mainline

SHELL ["/bin/bash", "-e", "-c"]
ENV DEBIAN_FRONTEND noninteractive

RUN <<EOT
apt-get update
apt-get install -y \
    busybox-static \
    logrotate \
    supervisor
apt-get clean
rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /usr/share/doc/*

mkdir -p /var/spool/cron/crontabs
echo '*/15 * * * * logrotate -v /etc/logrotate.conf' > /var/spool/cron/crontabs/root

mkdir -p /tmp/upload
chown www-data:www-data -R /tmp/upload
EOT

COPY ./*.conf /etc/
COPY ./crond /usr/bin/