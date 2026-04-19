FROM alpine:3.23.4

RUN apk --no-cache add dnsdist

ENTRYPOINT ["/usr/bin/dnsdist"]
CMD ["--supervised", "--config=/etc/dnsdist.conf"]
