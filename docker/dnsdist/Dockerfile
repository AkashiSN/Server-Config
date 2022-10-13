FROM alpine

RUN apk -U add dnsdist

ENTRYPOINT ["/usr/bin/dnsdist"]
CMD ["--config=/etc/dnsdist.conf"]