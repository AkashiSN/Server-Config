FROM alpine:3.21.2

RUN apk --no-cache add dnsdist

ENTRYPOINT ["/usr/bin/dnsdist"]
CMD ["--supervised", "--config=/etc/dnsdist.conf"]
