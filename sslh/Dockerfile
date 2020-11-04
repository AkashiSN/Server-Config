FROM ubuntu:20.04 as build

ENV DEBIAN_FRONTEND noninteractive

RUN apt-get update && \
    apt-get install -y curl && \
    apt-get install -y build-essential libconfig-dev libsystemd-dev libcap-dev libpcre++-dev libbsd-dev libwrap0-dev

WORKDIR /workdir

ADD https://github.com/yrutschle/sslh/archive/v1.21c.tar.gz /workdir/sslh-1.21c.tar.gz
RUN tar xvf sslh-1.21c.tar.gz && \
    cd sslh-1.21c && \
    make USELIBWRAP=1 USELIBCAP=1 USESYSTEMD=1 USELIBBSD=1


FROM ubuntu:20.04

ENV DEBIAN_FRONTEND noninteractive

RUN apt-get update && \
    apt-get -y install iptables iproute2 libconfig9 libsystemd0 libcap2 libpcre++0v5 libbsd0 libwrap0 && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /usr/share/doc/*

COPY --from=build /workdir/sslh-1.21c/sslh-fork /usr/sbin/sslh-fork
COPY --from=build /workdir/sslh-1.21c/sslh-select /usr/sbin/sslh-select

EXPOSE 443
ENTRYPOINT [ "/usr/sbin/sslh-select" ]
CMD [ "--verbose", "0", "--foreground", "--user", "root", "--listen", "0.0.0.0:443", "--tls", "nginx:443", "--openvpn", "openvpn:443", "--pidfile", "/var/run/sslh.pid" ]
