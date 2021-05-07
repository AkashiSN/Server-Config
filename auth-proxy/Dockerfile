FROM golang:1.16-buster as build

WORKDIR /go/src/github.com/AkashiSN/Server-Config/auth-proxy

COPY . .

RUN go build -o auth-proxy


# Final image
FROM gcr.io/distroless/base-debian10

COPY --from=build /go/src/github.com/AkashiSN/Server-Config/auth-proxy/auth-proxy /

EXPOSE 80
ENTRYPOINT [ "/auth-proxy" ]
