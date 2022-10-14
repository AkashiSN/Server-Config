FROM alpine

RUN apk -U add dnsmasq curl && \
    curl -sL -o /etc/dnsmasq.d/blacklist.conf https://github.com/notracking/hosts-blocklists/raw/master/dnsmasq/dnsmasq.blacklist.txt

ENTRYPOINT ["/usr/sbin/dnsmasq"]
CMD ["--keep-in-foreground", "--conf-dir=/etc/dnsmasq.d/"]