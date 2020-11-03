FROM ubuntu:20.04

ENV DEBIAN_FRONTEND noninteractive

RUN apt-get update && \
    apt-get install -y curl apt-transport-https ca-certificates gnupg-agent software-properties-common

RUN curl -s https://swupdate.openvpn.net/repos/repo-public.gpg | apt-key add && \
    add-apt-repository \
        "deb [arch=amd64] https://build.openvpn.net/debian/openvpn/stable \
        $(lsb_release -cs) \
        main" && \
    apt-get update && \
    apt-get install -y openvpn

WORKDIR /opt/openvpn

RUN ln -s /usr/lib/ssl/misc/CA.pl /usr/bin/CA.pl

EXPOSE 443
ENTRYPOINT [ "/opt/openvpn/run.sh" ]
