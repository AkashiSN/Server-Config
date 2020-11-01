FROM golang:1.15-alpine as go

WORKDIR /workdir

COPY . .

RUN go build -o auth

FROM alpine

EXPOSE 8888

COPY --from=go /workdir/auth-proxy /usr/bin/

ENTRYPOINT /usr/bin/auth-proxy
