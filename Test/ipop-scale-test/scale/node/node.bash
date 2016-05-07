#!/bin/bash

NEW_TEST=true # true=15.04 or later; false=14.10 or earlier

cd $(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

# keep $min $max and $nr_vnodes persistent
HELP_FILE="./HELP_FILE.txt"
if [ -e $HELP_FILE ]; then
    min=$(cat $HELP_FILE | grep MIN | awk '{print $2}')
    max=$(cat $HELP_FILE | grep MAX | awk '{print $2}')
    nr_vnodes=$(cat $HELP_FILE | grep NR_VNODES | awk '{print $2}')
else
    echo -e "MIN x\nMAX x\nNR_VNODES x" > $HELP_FILE
fi

# configuration file paths
if [ $NEW_TEST == true ]; then
    NODE_EJABBERD_CONFIG="./config/ejabberd.yml"
    EJABBERD_CONFIG='/etc/ejabberd/ejabberd.yml'
else
    NODE_EJABBERD_CONFIG="./config/ejabberd.cfg"
    EJABBERD_CONFIG='/etc/ejabberd/ejabberd.cfg'
fi

NODE_TURNSERVER_CONFIG="./config/turnserver.conf"
TURNSERVER_CONFIG='/etc/turnserver/turnserver.conf'
TURNSERVER_USERS='/etc/turnserver/turnusers.txt'

DEFAULT_LXC_CONFIG='/var/lib/lxc/default/config'
DEFAULT_LXC_PACKAGES='python psmisc iperf'

FORWARDER_PROGRAM="./forwarder.py"
IPOP_PATH="./ipop"
LXC_IPOP_SCRIPT='/home/ubuntu/ipop/ipop.bash'

case $1 in

    ("install")
        ### obtain network device and ip4 address
        NET_TEST=$(ip route get 8.8.8.8)
        NET_DEV=$(echo $NET_TEST | awk '{print $5}')
        NET_IP4=$(echo $NET_TEST | awk '{print $7}')

        ### update and upgrade
        sudo apt-get update
        sudo apt-get -y upgrade

        ### install LXC
        # install LXC package
        sudo apt-get -y install lxc

        # create default container
        sudo lxc-create -n default -t ubuntu

        # install additional packages; allow tap device
        sudo chroot /var/lib/lxc/default/rootfs apt-get update
        sudo chroot /var/lib/lxc/default/rootfs apt-get -y install $DEFAULT_LXC_PACKAGES
        echo 'lxc.cgroup.devices.allow = c 10:200 rwm' | sudo tee --append $DEFAULT_LXC_CONFIG

        ### install ejabberd
        # install ejabberd package
        sudo apt-get update
        sudo apt-get -y install ejabberd

        # prepare ejabberd server config file
        sudo cp $NODE_EJABBERD_CONFIG $EJABBERD_CONFIG

        # restart ejabberd service
        if [ $NEW_TEST == true ]; then
            sudo systemctl restart ejabberd.service
        else
            sudo ejabberdctl restart
        fi

        # wait for ejabberd service to start
        sleep 15

        # create admin user
        sudo ejabberdctl register admin ejabberd password

        ### install turnserver
        # install turnserver package
        sudo apt-get -y install turnserver

        # use IP aliasing to bind turnserver to this ipv4 address
        sudo ifconfig $NET_DEV:0 $NET_IP4 up

        # prepare turnserver config file
        sudo sed -i "s/listen_address = .*/listen_address = { \"$NET_IP4\" }/g" $NODE_TURNSERVER_CONFIG
        sudo cp $NODE_TURNSERVER_CONFIG $TURNSERVER_CONFIG

        ### configure network
        # replace symmetric NATs (MASQUERAGE) with full-cone NATs (SNAT)
        for i in $(sudo iptables -L POSTROUTING -t nat --line-numbers | awk '$2=="MASQUERADE" {print $1}'); do
            sudo iptables -t nat -D POSTROUTING $i
        done
        sudo iptables -t nat -A POSTROUTING -o $NET_DEV -j SNAT --to-source $NET_IP4

        # open TCP ports (for ejabberd)
        for i in 5222 5269 5280; do
            sudo iptables -A INPUT -p tcp --dport $i -j ACCEPT
            sudo iptables -A OUTPUT -p tcp --dport $i -j ACCEPT
        done

        # open UDP ports (for STUN and TURN)
        for i in 3478 19302; do
            sudo iptables -A INPUT -p udp --sport $i -j ACCEPT
            sudo iptables -A OUTPUT -p udp --sport $i -j ACCEPT
        done
        ;;
    ("init-containers")
        min=$2
        max=$3

        # keep $min and $max persistent
        sed -i "s/MIN.*/MIN $min/g" $HELP_FILE
        sed -i "s/MAX.*/MAX $max/g" $HELP_FILE

        # clone and start N containers from default container; create tap device
        for i in $(seq $min $max); do
            sudo bash -c "
                lxc-clone default node$i;
                sudo lxc-start -n node$i --daemon;
                sudo lxc-attach -n node$i -- bash -c 'sudo mkdir /dev/net; sudo mknod /dev/net/tun c 10 200; sudo chmod 0666 /dev/net/tun';
            " &
        done
        wait 
        ;;
    ("init-server")
        nr_vnodes=$2

        ### initialize XMPP/STUN services
        # keep $nr_vnodes persistent
        sed -i "s/NR_VNODES.*/NR_VNODES $nr_vnodes/g" $HELP_FILE

        # register IPOP users (username: node#@ejabberd, password: password)
        for i in $(seq 0 $(($nr_vnodes - 1))); do
            sudo ejabberdctl register "node$i" ejabberd password
        done

        # define user links
        if [ $NEW_TEST == true ]; then
            sudo ejabberdctl srg_create ipop_vpn ejabberd ipop_vpn ipop_vpn ipop_vpn
            sudo ejabberdctl srg_user_add @all@ ejabberd ipop_vpn ejabberd
        else
            for i in `seq 0 $(($nr_vnodes - 1))`; do
                for j in `seq 0 $(($nr_vnodes - 1))`; do
                    if [ "$i" != "$j" ]; then
                        sudo ejabberdctl add_rosteritem "node$i" ejabberd "node$j" ejabberd "node$j" ipop both
                        echo "added roster: $i $j"
                    fi
                done
            done
        fi

        ### initialize TURN service
        # keep $nr_vnodes persistent
        sed -i "s/NR_VNODES.*/NR_VNODES $nr_vnodes/g" $HELP_FILE

        # add users to turnserver userlist
        for i in $(seq 0 $(($nr_vnodes - 1))); do
            echo "node$i:password:socialvpn.org:authorized" | sudo tee --append $TURNSERVER_USERS
        done

        # run turnserver
        turnserver -c $TURNSERVER_CONFIG
        ;;
    ("restart-server")
        ### restart services
        # restart ejabberd
        if [ $NEW_TEST == true ]; then
            sudo systemctl restart ejabberd.service
        else
            sudo ejabberdctl restart
        fi

        # restart turnserver
        ps aux | grep -v grep | grep turnserver | awk '{print $2}' | xargs sudo kill -9
        turnserver -c $TURNSERVER_CONFIG
        ;;
    ("clear-containers")
        # stop and delete N containers
        for i in $(seq $min $max); do
            sudo lxc-stop -n "node$i"; sudo lxc-destroy -n "node$i" &
        done
        wait
        ;;
    ("clear-server")
        ### exit XMPP/STUN services
        # undefine user links
        sudo ejabberdctl srg_delete ipop_vpn ejabberd

        ### exit XMPP/STUN services
        # undefine user links
        if [ $NEW_TEST == true ]; then
            sudo ejabberdctl srg_delete ipop_vpn ejabberd
        else
            for i in `seq 0 $(($nr_vnodes - 1))`; do
                for j in `seq 0 $(($nr_vnodes - 1))`; do
                    if [ "$i" != "$j" ]; then
                        sudo ejabberdctl delete_rosteritem "node$i" ejabberd "node$j" ejabberd
                    fi
                done
            done
        fi

        # unregister IPOP users
        for i in $(seq 0 $(($nr_vnodes - 1))); do
            sudo ejabberdctl unregister "node$i" ejabberd
        done

        ### exit TURN service
        # kill turnserver
        ps aux | grep -v grep | grep turnserver | awk '{print $2}' | xargs sudo kill -9

        # remove users from turnserver userlist
        echo "" | sudo tee $TURNSERVER_USERS
        ;;
    ("source")
        # update sources of each vnode
        for i in $(seq $min $max); do
            sudo cp -r $IPOP_PATH "/var/lib/lxc/node$i/rootfs/home/ubuntu/" &
        done
        wait
        ;;
    ("config")
        params=${@:2}

        # create config file for each node
        for i in $(seq $min $max); do
            sudo lxc-attach -n "node$i" -- bash -c "bash $LXC_IPOP_SCRIPT config $i $params" &
        done
        wait
        ;;
    ("forward")
        forwarder_addr=$2
        forwarder_port=$3
        forwarded_port=$4

        ps aux | grep -v grep | grep $FORWARDER_PROGRAM | awk '{print $2}' | xargs sudo kill -9
        python3 $FORWARDER_PROGRAM $forwarder_addr $forwarder_port $forwarded_port
        ;;
    ("run")
        vnode_list=($2)

        for vnode in ${vnode_list[@]}; do
            sudo lxc-attach -n "node$vnode" -- bash -c "bash $LXC_IPOP_SCRIPT run"
        done
        ;;
    ("kill")
        vnode_list=($2)

        for vnode in ${vnode_list[@]}; do
            sudo lxc-attach -n "node$vnode" -- bash -c "bash $LXC_IPOP_SCRIPT kill"
        done
        ;;
    (*)
        echo "invalid operation"
        ;;

esac

exit 0

