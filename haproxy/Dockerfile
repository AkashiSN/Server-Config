FROM haproxy:2.3

RUN apt-get update && \
    apt-get install -y iptables iproute2 && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /usr/share/doc/*

COPY haproxy.cfg /usr/local/etc/haproxy/haproxy.cfg

COPY docker-entrypoint.sh /
ENTRYPOINT ["docker-entrypoint.sh"]

CMD ["haproxy", "-f", "/usr/local/etc/haproxy/haproxy.cfg"]

