#!/bin/bash

exp_dir=~/workspace/experiment

function prereqs
{
  sudo bash -c "
    apt-get update -y && \
    apt-get install -y openvswitch-switch=2.9.2-0ubuntu0.18.04.3 \
                        python3.6 python3-pip python3-venv \
                        apt-transport-https \
                        ca-certificates \
                        curl git \
                        software-properties-common && \

    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add - && \
    add-apt-repository \"deb [arch=amd64] https://download.docker.com/linux/ubuntu bionic stable\" && \
    apt-cache policy docker-ce && \
    apt-get install -y containerd.io=1.2.6-3 \
                       docker-ce-cli=5:18.09.7~3-0~ubuntu-bionic \
                       docker-ce=5:18.09.7~3-0~ubuntu-bionic && \
    groupadd -f docker && \
    usermod -a -G docker $USER \
  "
}

function venv
{
  cd $exp_dir
  python3 -m venv exp-venv
  source exp-venv/bin/activate
  pip3 install simplejson==3.16.0
}

function openfire
{
  apt-get install -y openjdk-8-jdk
  wget https://www.igniterealtime.org/downloadServlet?filename=openfire/openfire_4.4.1_all.deb \
    -O openfire_4.4.1_all.deb
  apt-get install -y ./openfire_4.4.1_all.deb
}

function netviz
{
  git clone https://github.com/ipop-project/Network-Visualizer.git
  cd Network-Visualizer/setup
  ./setup.sh
  chown -R $USER /users/$USER/Network-Visualizer
}

case $1 in
  prereqs)
    prereqs
    ;;
  venv)
    venv
    ;;
  xmpp)
    openfire
    ;;
  netviz)
    netviz
    ;;
  *)
    echo "no match on input -> $1"
    ;;
esac
