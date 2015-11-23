#!/bin/bash

cd $(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

# determine ethernet device and host ipv4 address
ETH_DEV=$(ifconfig | grep eth | awk '{print $1}' | head -n 1)
HOST_IPv4=$(ifconfig $ETH_DEV | grep "inet addr" | awk -F: '{print $2}' | awk '{print $1}')

# keep $min $max $nodeid and $nr_nodes persistent
HELP_FILE="./HELP_FILE.txt"
if [ -e $HELP_FILE ]; then
    min=$(cat $HELP_FILE | grep MIN | awk '{print $2}')
    max=$(cat $HELP_FILE | grep MAX | awk '{print $2}')
    #nr_vnodes=$(cat $HELP_FILE | grep NR_VNODES | awk '{print $2}')
    nr_nodes=$(cat $HELP_FILE | grep NR_NODES | awk '{print $2}')
    nodeid=$(cat $HELP_FILE | grep NODEID | awk '{print $2}')
else
    echo -e "MIN x\nMAX x\nNR_NODES x\nNODEID x" > $HELP_FILE
fi

# configuration file paths
NODE_EJABBERD_CONFIG="./config/ejabberd.yml"
EJABBERD_CONFIG='/etc/ejabberd/ejabberd.yml'

NODE_TURNSERVER_CONFIG="./config/turnserver.conf"
TURNSERVER_CONFIG='/etc/turnserver/turnserver.conf'
TURNSERVER_USERS='/etc/turnserver/turnusers.txt'

DEFAULT_LXC_CONFIG='/var/lib/lxc/default/config'
IPOP_TINCAN="./ipop-tincan-x86_64"
FORWARDER_PROGRAM="./cv_forwarder.py"
IPOP_CONTROLLER="controller.Controller"
GVPN_CONFIG="./controller/modules/gvpn-config.json"
#IPOP_PATH="./ipop"
#LXC_IPOP_SCRIPT='/home/ubuntu/ipop/ipop.bash'

case $1 in

    ("install")
        ### install LXC
        # install LXC package
        sudo apt-get update
        sudo apt-get -y install lxc

        # create default container
        sudo lxc-create -n default -t ubuntu

        # install additional packages (python and psmisc); allow tap device
        sudo chroot /var/lib/lxc/default/rootfs apt-get update
        sudo chroot /var/lib/lxc/default/rootfs apt-get install -y python psmisc iperf
        echo 'lxc.cgroup.devices.allow = c 10:200 rwm' | sudo tee --append $DEFAULT_LXC_CONFIG

        ### install ejabberd
        # install ejabberd package
        sudo apt-get update
        sudo apt-get -y install ejabberd

        # prepare ejabberd server config file
        sudo cp $NODE_EJABBERD_CONFIG $EJABBERD_CONFIG

        # restart ejabberd service
        sudo systemctl restart ejabberd.service
        sudo ejabberdctl restart

        # wait for ejabberd service to start
        sleep 15

        # create admin user
        sudo ejabberdctl register admin ejabberd password

        ### install turnserver
        # install libconfuse0 and turnserver packages
        sudo apt-get update
        sudo apt-get -y install libconfuse0 turnserver

        # use IP aliasing to bind turnserver to this ipv4 address
        sudo ifconfig $ETH_DEV:0 $HOST_IPv4 up

        # prepare turnserver config file
        sudo sed -i "s/listen_address = .*/listen_address = { \"$HOST_IPv4\" }/g" $NODE_TURNSERVER_CONFIG
        sudo cp $NODE_TURNSERVER_CONFIG $TURNSERVER_CONFIG

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
	nodeid=$4
        # keep $min and $max and $nodeid persistent
        sed -i "s/MIN.*/MIN $min/g" $HELP_FILE
        sed -i "s/MAX.*/MAX $max/g" $HELP_FILE
	sed -i "s/NODEID.*/NODEID $nodeid/g" $HELP_FILE
        # clone and start N containers from default container
        for i in $(seq $min $max); do
            sudo bash -c "
                lxc-clone default node$i;
        " &
        done

	# change lxcbr0 ip address
	sudo sed -i "s/10.0.3.1/10.0.3.$(($4 + 1))/g" /etc/default/lxc-net
	# restart lxc-net
        sudo service lxc-net restart
        wait 
        ;;
    ("init-server")
        nr_nodes=$2

        ### initialize XMPP/STUN services
        # keep $nr_nodes persistent
        sed -i "s/NR_NODES.*/NR_NODES $nr_nodes/g" $HELP_FILE

        # register IPOP users (username: node#@ejabberd, password: password)
        for i in $(seq 0 $(($nr_nodes - 1))); do
            sudo ejabberdctl register "node$i" ejabberd password
        done

        # define user links
        sudo ejabberdctl srg_create ipop_vpn ejabberd ipop_vpn ipop_vpn ipop_vpn
        sudo ejabberdctl srg_user_add @all@ ejabberd ipop_vpn ejabberd

        ### initialize TURN service

        # add users to turnserver userlist
        for i in $(seq 0 $(($nr_nodes - 1))); do
            echo "node$i:password:socialvpn.org:authorized" | sudo tee --append $TURNSERVER_USERS
        done

        # run turnserver
        turnserver -c $TURNSERVER_CONFIG
        ;;
    ("restart-server")
        ### restart services
        # restart ejabberd
        sudo systemctl restart ejabberd.service
        sudo ejabberdctl restart

        # restart turnserver
        ps aux | grep -v grep | grep turnserver | awk '{print $2}' | xargs sudo kill -9
        turnserver -c $TURNSERVER_CONFIG
        ;;
    ("exit-containers")
        # stop and delete N containers
        for i in $(seq $min $max); do
            sudo lxc-stop -n "node$i"; sudo lxc-destroy -n "node$i" &
        done
        wait
        ;;
    ("exit-server")
        ### exit XMPP/STUN services
        # undefine user links
        sudo ejabberdctl srg_delete ipop_vpn ejabberd

        # unregister IPOP users
        for i in $(seq 0 $(($nr_nodes - 1))); do
            sudo ejabberdctl unregister "node$i" ejabberd
        done

        ### exit TURN service
        # kill turnserver
        ps aux | grep -v grep | grep turnserver | awk '{print $2}' | xargs sudo kill -9

        # remove users from turnserver userlist
        echo "" | sudo tee $TURNSERVER_USERS
        ;;
    ("config")
            # parse and prepare arguments
            xmpp_username="node$nodeid@ejabberd"
            xmpp_password="password"
            xmpp_host=$2
            stun=$3
            turn='{"server": "'$4'", "user": "node'$i'", "pass": "password"}'
            ipv4='172.31.'$(($nodeid / 256))'.'$(($(($nodeid + 1)) % 256))
            ipv4_mask=16
            central_visualizer=$5
            central_visualizer_ipv4=$6
            central_visualizer_port=$7
            num_successors=$8
            num_chords=$9
            num_on_demand=${10}
            num_inbound=${11}

            ttl_link_initial=${12}
            ttl_link_pulse=${13}

            ttl_chord=${14}
            ttl_on_demand=${15}

            threshold_on_demand=${16}
	    interval_management=15
            interval_central_visualizer=5
	    
	# create config file
        echo -e \
            "{"\
            "\n  \"CFx\": {"\
            "\n    \"xmpp_username\": \"$xmpp_username\","\
            "\n    \"xmpp_password\": \"$xmpp_password\","\
            "\n    \"xmpp_host\": \"$xmpp_host\","\
            "\n    \"tincan_logging\": 0,"\
            "\n    \"vpn_type\": \"GroupVPN\","\
            "\n    \"ip4_mask\": $ipv4_mask,"\
            "\n    \"stat_report\": false"\
            "\n  },"\
            "\n  \"Logger\": {"\
            "\n    \"controller_logging\": \"ERROR\""\
            "\n  },"\
            "\n  \"TincanSender\": {"\
            "\n    \"switchmode\": 1,"\
            "\n    \"stun\": [\"$stun\"],"\
            "\n    \"turn\": [$turn],"\
            "\n    \"dependencies\": [\"Logger\"]"\
            "\n  },"\
            "\n  \"BaseTopologyManager\": {"\
            "\n    \"ip4\": \"$ipv4\","\
            "\n    \"sec\": true,"\
            "\n    \"multihop\": false,"\
            "\n    \"num_successors\": $num_successors,"\
            "\n    \"num_chords\": $num_chords,"\
            "\n    \"num_on_demand\": $num_on_demand,"\
            "\n    \"num_inbound\": $num_inbound,"\
            "\n    \"ttl_link_initial\": $ttl_link_initial,"\
            "\n    \"ttl_link_pulse\": $ttl_link_pulse,"\
            "\n    \"ttl_chord\": $ttl_chord,"\
            "\n    \"ttl_on_demand\": $ttl_on_demand,"\
            "\n    \"threshold_on_demand\": $threshold_on_demand,"\
            "\n    \"timer_interval\": 1,"\
            "\n    \"interval_management\": $interval_management,"\
            "\n    \"interval_central_visualizer\": $interval_central_visualizer,"\
            "\n    \"dependencies\": [\"Logger\", \"CentralVisualizer\"]"\
            "\n  },"\
            "\n  \"LinkManager\": {"\
            "\n    \"dependencies\": [\"Logger\"]"\
            "\n  },"\
            "\n  \"TincanDispatcher\": {"\
            "\n    \"dependencies\": [\"Logger\"]"\
            "\n  },"\
            "\n  \"TincanListener\" : {"\
            "\n    \"socket_read_wait_time\": 15,"\
            "\n    \"dependencies\": [\"Logger\", \"TincanDispatcher\"]"\
            "\n  },"\
            "\n    \"StatReport\": {"\
            "\n    \"stat_report\": false,"\
            "\n    \"stat_server\": \"metrics.ipop-project.org\","\
            "\n    \"stat_server_port\": 5000,"\
            "\n    \"timer_interval\": 200"\
            "\n  },"\
            "\n  \"CentralVisualizer\": {"\
            "\n    \"central_visualizer\": $central_visualizer,"\
            "\n    \"central_visualizer_addr\": \"$central_visualizer_ipv4\","\
            "\n    \"central_visualizer_port\": $central_visualizer_port,"\
            "\n    \"dependencies\": [\"Logger\"]"\
            "\n  }"\
            "\n}"\
            > $GVPN_CONFIG
          
        wait
        ;;
    ("forward")
        dbg_visual_ipv4=$2
        dbg_visual_port=$3
        forward_port=$4

        ps aux | grep -v grep | grep $FORWARDER_PROGRAM | awk '{print $2}' | xargs sudo kill -9
        python3 $FORWARDER_PROGRAM $dbg_visual_ipv4 $dbg_visual_port $forward_port
        ;;
    ("run")
	# start the tincan and controller
        sudo chmod +x $IPOP_TINCAN
	sudo sh -c './ipop-tincan-x86_64 1> out.log 2> err.log &'
        python -m $IPOP_CONTROLLER -c $GVPN_CONFIG &> log.txt &
	sudo brctl addif lxcbr0 ipop
        ;;
    ("kill")
	# kill the tincan and controller
	ps aux | grep -v grep | grep $IPOP_TINCAN | awk '{print $2}' | xargs sudo kill -9
	ps aux | grep -v grep | grep $IPOP_CONTROLLER | awk '{print $2}' | xargs sudo kill -9
        ;;
    ("start")
        vnode_list=($2)	
	for i in ${vnode_list[@]}; do
	    NEW_IP=10.0.3."$((100 + $i))"
	    # set the static ip of each lxc
            sudo chroot /var/lib/lxc/"node$i"/rootfs sed -i "s/iface eth0 inet dhcp/iface eth0 inet static\naddress $NEW_IP\ngateway 10.0.3.$(($nodeid + 1))\nnetmask 255.255.255.0/g" /etc/network/interfaces
	    sudo lxc-start -n node$i --daemon    
        done
        ;;
    ("stop")
        vnode_list=($2)
        for vnode in ${vnode_list[@]}; do
            sudo lxc-stop -n "node$vnode"
        done
        ;;
    ("mem")
	tincan_pid=$(ps aux | grep -v grep | grep tincan | grep -v sudo | awk '{print $2}' | head -n 1)
	top -n 1 -b -p $tincan_pid
        ;;
    ("iperf")
	    case $2 in
                ("c")
		    vnode=$3
		    ip=$4
	 	    type=$5
	 	    if [ "$type" == "u" ]; then
  		  	sudo lxc-attach -n "node$vnode" -- iperf -u -c $ip
		    else
   			sudo lxc-attach -n "node$vnode" -- iperf -c $ip
		    fi
		    
                    ;;
                ("s")
		    vnode=$3
		    type=$4
		    if [ "$type" == "u" ]; then
  		  	sudo lxc-attach -n "node$vnode" -- iperf -u -s -D
		    else
   			sudo lxc-attach -n "node$vnode" -- iperf -s -D
		    fi
		   
                    ;;
                ("kill")
		    vnode=$3
		    iperf_pid=$(sudo lxc-attach -n "node$vnode" -- ps aux | grep iperf | awk '{print$2}' | head -n 1)
		    sudo lxc-attach -n "node$vnode" -- sudo kill -9 $iperf_pid
                    ;;
            esac
        ;;
    ("ping")
	vnode=$2
	ip=$3
	count=$4
	if [ -z $count ]; then
       		sudo lxc-attach -n "node$vnode" -- ping $ip
	else
        	sudo lxc-attach -n "node$vnode" -- ping $ip -c $count 
	fi
        
	;;
    ("getip")
	vnode=$2
	node_ETH_DEV=$(sudo lxc-attach -n "node$vnode" -- ifconfig | grep eth | awk '{print $1}' | head -n 1)
	node_IPv4=$(sudo lxc-attach -n "node$vnode" -- ifconfig $node_ETH_DEV | grep "inet addr" | awk -F: '{print $2}' | awk '{print $1}')
	echo $node_IPv4
	;;
    ("getvip")
	vnode=$2
	node_IPOP_DEV=$(sudo lxc-attach -n "node$vnode" -- ifconfig | grep ipop | awk '{print $1}' | head -n 1)
	node_Vip=$(sudo lxc-attach -n "node$vnode" -- ifconfig $node_IPOP_DEV | grep "inet addr" | awk -F: '{print $2}' | awk '{print $1}')
	echo $node_Vip
	;;
    (*)
        echo "invalid operation"
        ;;

esac

exit 0

