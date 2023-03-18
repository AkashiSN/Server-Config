FROM alpine

RUN apk --no-cache add dnsmasq curl && \
    echo '#!/bin/sh' > /docker-entrypoint.sh && \
    echo 'curl -L -o /etc/dnsmasq.d/blacklist.conf https://github.com/notracking/hosts-blocklists/raw/master/dnsmasq/dnsmasq.blacklist.txt' >> /docker-entrypoint.sh && \
    echo 'exec "$@"' >> /docker-entrypoint.sh && \
    chmod +x /docker-entrypoint.sh

ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["/usr/sbin/dnsmasq", "--keep-in-foreground", "--conf-dir=/etc/dnsmasq.d/"]