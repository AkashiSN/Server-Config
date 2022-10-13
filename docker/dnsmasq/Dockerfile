FROM alpine

RUN apk -U add dnsmasq curl && \
    curl -sL -o /etc/dnsmasq.blacklist.conf https://github.com/notracking/hosts-blocklists/raw/master/dnsmasq/dnsmasq.blacklist.txt

ADD dnsmasq.conf /etc/dnsmasq.conf

ENTRYPOINT ["/usr/sbin/dnsmasq"]
CMD ["--keep-in-foreground", "--conf-file=/etc/dnsmasq.conf"]