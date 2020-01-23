#!/bin/bash

bash -c "
    cp ./setup/99fixbadproxy /etc/apt/apt.conf.d/99fixbadproxy && \
        systemctl mask getty@tty1.service && \
        apt-get update -y && \
        apt-get install -y \
            psmisc \
            iputils-ping \
            nano \
            python3.6 \
            python3.6-dev \
            python3-pip \
            iproute2 \
            iperf \
            openvswitch-switch \
            bridge-utils && \
        mkdir -p /opt/ipop-vpn && \
        cd /opt/ipop-vpn && \
        pip3 --no-cache-dir install virtualenv  && \
        virtualenv --python=python3.6 ipop-venv && \
        source ipop-venv/bin/activate && \
        pip3 --no-cache-dir install psutil==5.6.3 \
            sleekxmpp==1.3.3 \
            requests==2.21.0 \
            simplejson==3.16.0 && \
        deactivate"
