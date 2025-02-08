FROM alpine:3.21.2

RUN apk --no-cache add dnsmasq curl && \
    echo '#!/bin/sh' > /docker-entrypoint.sh && \
    echo 'curl -L -o /etc/dnsmasq.d/blacklist.conf https://raw.githubusercontent.com/hagezi/dns-blocklists/main/dnsmasq/pro.plus.txt' >> /docker-entrypoint.sh && \
    echo 'exec "$@"' >> /docker-entrypoint.sh && \
    chmod +x /docker-entrypoint.sh

ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["/usr/sbin/dnsmasq", "--keep-in-foreground", "--conf-dir=/etc/dnsmasq.d/"]
