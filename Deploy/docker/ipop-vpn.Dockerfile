FROM solita/ubuntu-systemd:18.04 as base
WORKDIR /root/
COPY ./setup/ ./setup/
RUN ./setup/setup-base.sh
# stage 2
FROM base
COPY ./setup/ipop-vpn_20.2.20_amd64.deb ./setup/ipop-vpn_20.2.20_amd64.deb
RUN apt-get install -y ./setup/ipop-vpn_20.2.20_amd64.deb && \
    rm -rf /var/lib/apt/lists/* && \
    apt-get autoclean && \
    rm -rf ./setup

CMD ["/sbin/init"]
