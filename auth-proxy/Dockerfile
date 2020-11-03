FROM golang:1.15-alpine as go

WORKDIR /workdir

COPY . .

RUN go build -o auth-proxy

FROM alpine

COPY --from=go /workdir/auth-proxy /usr/bin/

EXPOSE 80
ENTRYPOINT [ "/usr/bin/auth-proxy" ]
