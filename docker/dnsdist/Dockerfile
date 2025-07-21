FROM alpine:3.22.1

RUN apk --no-cache add dnsdist

ENTRYPOINT ["/usr/bin/dnsdist"]
CMD ["--supervised", "--config=/etc/dnsdist.conf"]
