FROM alpine

RUN apk -U add dnsdist

ENTRYPOINT ["/usr/bin/dnsdist"]
CMD ["--supervised", "--config=/etc/dnsdist.conf"]