FROM alpine:3.22.0

RUN apk --no-cache add dnsdist

ENTRYPOINT ["/usr/bin/dnsdist"]
CMD ["--supervised", "--config=/etc/dnsdist.conf"]
