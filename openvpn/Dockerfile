FROM ubuntu:20.04

ENV DEBIAN_FRONTEND noninteractive

RUN apt-get update && \
    apt-get install -y curl apt-transport-https ca-certificates gnupg-agent software-properties-common && \
    curl -s https://swupdate.openvpn.net/repos/repo-public.gpg | apt-key add && \
    add-apt-repository \
        "deb [arch=amd64] https://build.openvpn.net/debian/openvpn/stable \
        $(lsb_release -cs) \
        main" && \
    apt-get update && \
    apt-get install -y openvpn && \
    apt-get install -y iptables iproute2 && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /usr/share/doc/*

WORKDIR /opt/openvpn

EXPOSE 1194/udp
EXPOSE 1194/tcp

ENTRYPOINT [ "/opt/openvpn/run.sh" ]
