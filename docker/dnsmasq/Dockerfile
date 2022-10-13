FROM alpine

RUN apk -U add dnsmasq curl && \
    curl -sL -o /etc/dnsmasq.blacklist.conf https://github.com/notracking/hosts-blocklists/raw/master/dnsmasq/dnsmasq.blacklist.txt

ADD dnsmasq.conf /etc/dnsmasq.conf

ENTRYPOINT ["dnsmasq", "-k", "-b", "-B", "0.0.0.0", "-C", "/etc/dnsmasq.conf", "--cache-size=1500"]