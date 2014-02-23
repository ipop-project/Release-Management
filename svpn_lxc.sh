#!/bin/sh
# this script uses lxc to run multiple instances of SocialVPN
# this script is designed for Ubuntu 12.04 (64-bit)
#
# usage: svpn_lxc.sh 1 10 30"

CONTAINER_START=$1
CONTAINER_END=$2
WAIT_TIME=$3
MODE=$4
HOST=$(hostname)
CONTROLLER=svpn_controller.py
START_PATH=container/rootfs/home/ubuntu/start.sh

sudo apt-get update
sudo apt-get install -y lxc

wget -O ubuntu.tgz http://goo.gl/Ze7hYz
wget -O container.tgz http://goo.gl/XJgdtf

sudo tar xzf ubuntu.tgz; tar xzf container.tgz
sudo cp -a ubuntu/* container/rootfs/
sudo mv container/home/ubuntu container/rootfs/home/ubuntu/
mv ipop container/rootfs/home/ubuntu/ipop/

cat > $START_PATH << EOF
#!/bin/bash
SVPN_HOME=/home/ubuntu/ipop
\$SVPN_HOME/ipop-tincan-x86_64 &> \$SVPN_HOME/svpn_log.txt &
python \$SVPN_HOME/$CONTROLLER -c \$SVPN_HOME/config.json &> \$SVPN_HOME/controller_log.txt &
EOF

chmod 755 $START_PATH

lxc_path=/var/lib/lxc
sudo chmod 755 $lxc_path

for i in $(seq $CONTAINER_START $CONTAINER_END)
do
    container_name=container$i
    container_path=$lxc_path/$container_name

    sudo cp -a container $container_name

    sudo mv $container_name $lxc_path
    sudo echo "lxc.rootfs = $container_path/rootfs" >> $container_path/config
    sudo echo "lxc.mount = $container_path/fstab" >> $container_path/config
    sudo lxc-start -n $container_name -d
    sleep $WAIT_TIME
done

