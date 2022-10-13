FROM alpine

RUN apk -U add dnsdist

ADD dnsdist.conf /etc/dnsdist.conf

ENTRYPOINT ["/usr/bin/dnsdist"]