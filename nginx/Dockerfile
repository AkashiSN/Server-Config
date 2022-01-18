FROM nginx:mainline

ENV DEBIAN_FRONTEND noninteractive

RUN apt-get update && \
    apt-get install -y supervisor logrotate busybox-static && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /usr/share/doc/* && \
    mkdir -p /var/spool/cron/crontabs && \
    echo '*/15 * * * * logrotate -v /etc/logrotate.conf' > /var/spool/cron/crontabs/root && \
    mkdir -p /tmp/upload && \
    chown www-data:www-data -R /tmp/upload

COPY supervisord.conf /etc/
COPY logrotate.conf /etc/
COPY cron.sh /usr/bin/

RUN chmod 644 /etc/logrotate.conf && \
    chmod +x /usr/bin/cron.sh