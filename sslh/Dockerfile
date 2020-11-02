FROM ubuntu:20.04

ENV DEBIAN_FRONTEND noninteractive

RUN apt-get update && \
    apt-get install -y curl && \
    apt-get install -y build-essential libconfig-dev libsystemd-dev libcap-dev libpcre++-dev libbsd-dev libwrap0-dev

WORKDIR /workdir

ADD https://github.com/yrutschle/sslh/archive/v1.21c.tar.gz /workdir/sslh-1.21c.tar.gz
RUN tar xvf sslh-1.21c.tar.gz && \
    cd sslh-1.21c && \
    make USELIBWRAP=1 USELIBCAP=1 USESYSTEMD=1 USELIBBSD=1 && \
    make install

EXPOSE 443
ENTRYPOINT [ "usr/sbin/sslh" ]
