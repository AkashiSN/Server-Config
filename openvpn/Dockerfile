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

RUN apt-get install -y iptables iproute2 && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /usr/share/doc/*

WORKDIR /opt/openvpn

RUN /opt/openvpn/openssl.sh ${STATE_NAME} ${LOCALITY_NAME} ${ORGANIZATION_NAME} ${ROOT_CA_PASSPHRASE} ${VPN_SUBDOMAIN}.${DOMAIN} ${CLIENTS}

EXPOSE 443
ENTRYPOINT [ "/opt/openvpn/run.sh" ]
