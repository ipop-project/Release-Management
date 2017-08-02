#!/bin/bash

IPOP_HOME="/home/ubuntu/ipop"
IPOP_TINCAN="$IPOP_HOME/ipop-tincan"
IPOP_CONTROLLER="controller.Controller"
HELP_FILE="./auto_config_scale.txt"
TINCAN="./ipop-tincan"
CONTROLLER="./Controllers"
DEFAULT_LXC_PACKAGES='python psmisc iperf iperf3'
DEFAULT_LXC_CONFIG='/var/lib/lxc/default/config'
DEFAULT_TINCAN_REPO='https://github.com/ipop-project/Tincan'
DEFAULT_CONTROLLERS_REPO='https://github.com/ipop-project/Controllers'
DEFAULT_VISUALIZER_REPO='https://github.com/cstapler/IPOPNetVisualizer'
OS_VERSION=$(lsb_release -r -s)
VPNMODE=$(cat $HELP_FILE 2>/dev/null | grep MODE | awk '{print $2}')
min=$(cat $HELP_FILE 2>/dev/null | grep MIN | awk '{print $2}')
max=$(cat $HELP_FILE 2>/dev/null | grep MAX | awk '{print $2}')
nr_vnodes=$(cat $HELP_FILE 2>/dev/null | grep NR_VNODES | awk '{print $2}')
BRIDGE_COUNT=$(cat $HELP_FILE 2>/dev/null | grep BRIDGE_COUNT | awk '{print $2}')
NET_TEST=$(ip route get 8.8.8.8)
NET_DEV=$(echo $NET_TEST | awk '{print $5}')
NET_IP4=$(echo $NET_TEST | awk '{print $7}')
TURN_USERS="/etc/turnserver/turnusers.txt"
TURN_ROOT_CONFIG="/etc/turnserver/turnserver.conf"
TURN_CONFIG="./config/turnserver.conf"

function help()
{
    echo 'Enter from the following options:
    configure                      : install/prepare default container
    containers-create              : create and start containers
    containers-start               : start stopped containers
    containers-stop                : stop containers
    containers-del                 : delete containers
    ipop-run                       : to run IPOP node
    ipop-kill                      : to kill IPOP node
    ipop-tests                     : open scale test shell to test ipop
    ipop-status                    : show statuses of IPOP processes
    visualizer-start               : install and start up visualizer
    visualizer-stop                : stop visualizer processes
    visualizer-status              : show statuses of visualizer processes
    logs                           : aggregate ipop logs under ./logs
    mode                           : show or change ipop mode to test
    '
}


function options
{
    read -p "$(help) `echo $'\n> '`" user_input
    echo $user_input
}

function configure-bridges
{
    if [ -z "$BRIDGE_COUNT" ]; then
        read -p "Enter number of bridges to split containers between (Default 1): `echo $'\n> '`" user_input
        if [ -z "$user_input" ]; then
            user_input=2
        fi
        BRIDGE_COUNT=$user_input
        echo "BRIDGE_COUNT $user_input" >> $HELP_FILE
    else
        echo "BRIDGE COUNT set to $BRIDGE_COUNT"
    fi
    ### Create Bridges
    for (( CNTR=1; CNTR<$BRIDGE_COUNT; CNTR+=1 )); do
        CNTR_GATEWAY="10.$CNTR.3.1"
        CNTR_NETWORK="10.$CNTR.3.0/24"
        echo "creating lxcbr$CNTR"
        sudo brctl addbr "lxcbr$CNTR"
        for (( CNTR2=0; CNTR2<$CNTR; CNTR2+=1 )); do
            CNTR2_NETWORK="10.${CNTR2}.3.0/24"
            echo "setting up iptables to block local traffic between lxcbr$CNTR and lxcbr$CNTR2"
            sudo iptables -A FORWARD -s "$CNTR_NETWORK" -d "${CNTR2_NETWORK}" -j DROP
            sudo iptables -A FORWARD -s "${CNTR2_NETWORK}" -d "$CNTR_NETWORK" -j DROP
        done
        # Set up bridge interface ips
        echo "Setting up lxc net with Gateway: $CNTR_GATEWAY"
        sudo ifconfig "lxcbr$CNTR" "$CNTR_GATEWAY/24"
    done
}

function configure
{
    # if argument is true mongodb and ejabberd won't be installed
    is_external=$1

    #Python dependencies for visualizer and ipop python tests
    sudo apt-get install -y python python-pip python-lxc

    sudo pip install --upgrade pip
    sudo pip install pymongo

    if [[  ! ( "$is_external" = true ) ]]; then
        #Install and start mongodb for use ipop python tests
        sudo apt-get -y install mongodb
    fi

    #Prepare Tincan for compilation
    sudo add-apt-repository -y ppa:ubuntu-toolchain-r/test
    sudo apt-get update -y
    sudo apt-get -y install lxc g++-4.9
    sudo update-alternatives --install /usr/bin/g++ g++ /usr/bin/g++-4.9 10

    # Install ubuntu OS in the lxc-container
    sudo lxc-create -n default -t ubuntu
    sudo chroot /var/lib/lxc/default/rootfs apt-get -y update
    sudo chroot /var/lib/lxc/default/rootfs apt-get -y install $DEFAULT_LXC_PACKAGES
    sudo chroot /var/lib/lxc/default/rootfs apt-get -y install software-properties-common python-software-properties

    # install controller dependencies
    if [ $VPNMODE = "switch" ]; then
        sudo pip install sleekxmpp pystun psutil
    else
        sudo chroot /var/lib/lxc/default/rootfs apt-get -y install 'python-pip'
        sudo chroot /var/lib/lxc/default/rootfs pip install 'sleekxmpp' pystun psutil
    fi

    # allow tap devices to be used in containers
    lxc_device_option="lxc.cgroup.devices.allow = c 10:200 rwm"
    if [[ -z "$( sudo cat $DEFAULT_LXC_CONFIG | grep "$lxc_device_option" )" ]]; then
        echo "$lxc_device_option" | sudo tee --append $DEFAULT_LXC_CONFIG
    fi

    if [[ ! ( "$is_external" = true ) ]]; then
        # Install turnserver
        sudo apt-get install -y turnserver
        echo "containeruser:password:$NET_IP4:authorized" | sudo tee --append $TURN_USERS
        # use IP aliasing to bind turnserver to this ipv4 address
        sudo ifconfig $NET_DEV:0 $NET_IP4 up
        # prepare turnserver config file
        sudo cp $TURN_CONFIG $TURN_ROOT_CONFIG
        sudo sed -i "s/listen_address = .*/listen_address = { \"$NET_IP4\" }/g" $TURN_ROOT_CONFIG
        sudo systemctl restart turnserver
    fi

    # configure network
    # step 1 clear iptables settings
    sudo iptables --flush
    # step 2 setup bridges
    configure-bridges
    # step 3 bridge nat setup
    read -p "Use symmetric NATS? (Y/n) " use_symmetric_nat
    if [[ $use_symmetric_nat =~ [Nn]([Oo])* ]]; then
        # replace symmetric NATs (MASQUERAGE) with full-cone NATs (SNAT)
        sudo iptables -t nat -A POSTROUTING -o $NET_DEV -j SNAT --to-source $NET_IP4
    else
        for (( CNTR=0; CNTR<$BRIDGE_COUNT; CNTR+=1 )); do
             sudo iptables -t nat -A POSTROUTING -t nat -o "lxcbr$CNTR" -j MASQUERADE --random
             sudo iptables -A FORWARD -i "lxcbr$CNTR" -o $NET_DEV -m state --state ESTABLISHED,RELATED -j ACCEPT
             sudo iptables -A FORWARD -i $NET_DEV -o "lxcbr$CNTR" -j ACCEPT
             echo "SETTING UP lxcbr$CNTR in symmetric nat mode"
        done
    fi

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

    if [[ ! ( "$is_external" = true ) ]]; then
        # Install local ejabberd server
        sudo apt-get -y install ejabberd
        # prepare ejabberd server config file
        # restart ejabberd service
        if [ $OS_VERSION = '14.04' ]; then
            sudo cp ./config/ejabberd.cfg /etc/ejabberd/ejabberd.cfg
            sudo ejabberdctl restart
        else
            sudo apt-get -y install erlang-p1-stun
            sudo cp ./config/ejabberd.yml /etc/ejabberd/ejabberd.yml
            sudo systemctl restart ejabberd.service
        fi
        # Wait for ejabberd service to start
        sleep 15
        # Create admin user
        sudo ejabberdctl register admin ejabberd password
    fi
}

function containers-create
{
    # obtain network device and ip4 address
    NET_TEST=$(ip route get 8.8.8.8)
    NET_DEV=$(echo $NET_TEST | awk '{print $5}')
    NET_IP4=$(echo $NET_TEST | awk '{print $7}')

    MODELINE=$(cat $HELP_FILE | grep MODE)
    BRIDGELINE=$(cat $HELP_FILE | grep BRIDGE_COUNT)

    # function parameters
    container_count=$1
    controller_repo_url_arg=$2
    tincan_repo_url_arg=$3
    visualizer_arg=$4
    is_external=$5

    if [ -z "$container_count" ]; then
        read -p "No of containers to be created: " max
        min=1
        echo -e "MIN $min\nMAX $max\nNR_VNODES $max" > $HELP_FILE
        echo $MODELINE >> $HELP_FILE
        echo $BRIDGELINE >> $HELP_FILE
    else
        max=$container_count
        min=1
        echo -e "MIN 1\nMAX $max\nNR_VNODES $max" > $HELP_FILE
        echo $MODELINE >> $HELP_FILE
        echo $BRIDGELINE >> $HELP_FILE
    fi

    if [ -z "$controller_repo_url_arg" ]; then
        # Check if IPOP controller executables already exists
        if [ -e $CONTROLLER ]; then
            echo -e "\e[1;31mControllers repo already present in the current path. Continue with existing repo? (Y/N) \e[0m"
            read user_input
            if [[ "$user_input" =~ [Nn](o)* ]]; then
                rm -rf $CONTROLLER
                echo -e "\e[1;31mEnter IPOP Controller github URL(default: $DEFAULT_CONTROLLERS_REPO)\e[0m"
                read githuburl_ctrl
                if [ -z "$githuburl_ctrl" ]; then
                    githuburl_ctrl=$DEFAULT_CONTROLLERS_REPO
                fi
                git clone $githuburl_ctrl
                echo -e "\e[1;31mDo you want to continue using master branch? (Y/N):\e[0m"
                read user_input
                if [ $user_input = 'N' ]; then
                    echo -e "Enter git repo branch name:"
                    read github_branch
                    cd Controllers
                    git checkout $github_branch
                    cd ..
                fi
            fi
        else
            echo -e "\e[1;31mEnter IPOP Controller github URL(default: $DEFAULT_CONTROLLERS_REPO)\e[0m"
            read githuburl_ctrl
            if [ -z "$githuburl_ctrl" ]; then
                githuburl_ctrl=$DEFAULT_CONTROLLERS_REPO
            fi
            git clone $githuburl_ctrl
            echo -e "\e[1;31mDo you want to continue using master branch? (Y/N):\e[0m"
            read user_input
            if [[ "$user_input" =~ [Nn](o)* ]]; then
                echo -e "Enter git repo branch name:"
                read github_branch
                cd Controllers
                git checkout $github_branch
                cd ..
            fi
        fi
    else
        git clone $controller_repo_url_arg
    fi

    if [ -e $TINCAN ]; then
        echo "Using existing Tincan binary..."
    else
        if ! [ -e "./Tincan/trunk/build/" ]; then
            if [ -z "$tincan_repo_url_arg" ]; then
                echo -e "\e[1;31mEnter github URL for Tincan (default: $DEFAULT_TINCAN_REPO) \e[0m"
                read github_tincan
                if [ -z "$github_tincan" ] ; then
                    github_tincan=$DEFAULT_TINCAN_REPO
                fi
            else
                github_tincan=$tincan_repo_url_arg
            fi
            git clone $github_tincan
            echo -e "\e[1;31mDo you want to continue using master branch? (Y/N):\e[0m"
            read user_input
            if [[ "$user_input" =~ [Nn](o)* ]]; then
                echo -e "Enter git repo branch name:"
                read github_branch
                cd Tincan
                git checkout $github_branch
                cd ..
            fi
        fi
        cd ./Tincan/trunk/build/
        echo "Building Tincan binary"
        make
        cd ../../..
        cp ./Tincan/trunk/out/release/x64/ipop-tincan .        
    fi

    if [ -z "$visualizer_arg" ]; then
        echo -e "\e[1;31mEnable visualization? (Y/N): \e[0m"
        read visualizer
        if [[ "$visualizer" =~ [Yy](es)* ]]; then
            isvisual=true
        else
            isvisual=false
        fi
    else
        if [[ "$visualizer_arg" =~ [Yy](es)* ]]; then
            isvisual=true
        else
            isvisual=false
        fi
    fi

    topology_param="4 4 0 4"
    if [[ ! ( "$is_external" = true ) ]]; then
        echo "Network defaults:"
        echo "No of Successor links: 4"
        echo "Max No of Chords: 4"
        echo "Max No of Ondemand links: 0"
        echo "Max No of Inbound links: 4"
        echo -e "\e[1;31mDo you want to use IPOP network defaults? (Y/N): \e[0m"
        read user_input
        if [[ $user_input =~ [Nn](o)* ]]; then
            topology_param=""
            echo -e "\e[1;31mEnter No of Successor Links: \e[0m"
            read user_input
            topology_param="$topology_param $user_input"
            echo -e "\e[1;31mEnter Max No of Chords Links: \e[0m"
            read user_input
            topology_param="$topology_param $user_input"
            echo -e "\e[1;31mEnter Max No of Ondemand Links: \e[0m"
            read user_input
            topology_param="$topology_param $user_input"
            echo -e "\e[1;31mEnter Max No of Inbound Links: \e[0m"
            read user_input
            topology_param="$topology_param $user_input"
        fi
    fi
    echo -e "\e[1;31mStarting containers. Please wait... \e[0m"
    if [[ "$VPNMODE" = "switch" ]]; then
        sudo mkdir -p /dev/net
        sudo rm /dev/net/tun
        sudo mknod /dev/net/tun c 10 200
        sudo chmod 0666 /dev/net/tun
        sudo chmod +x ./ipop-tincan
        sudo chmod +x ./node/node_config.sh
        sudo cp -r ./Controllers/controller/ ./

        if [[ ! ( "$is_external" = true ) ]]; then
            sudo ./node/node_config.sh config 1 GroupVPN $NET_IP4 $isvisual $topology_param containeruser password
            sudo ejabberdctl register "node1" ejabberd password
        else
            sudo ./node/node_config.sh config 2 GroupVPN $NET_IP4 $isvisual $topology_param containeruser password
            sudo ejabberdctl register "node2" ejabberd password
        fi

        for i in $(seq $min $max); do
            sudo bash -c "
            lxc-copy -n default -N node$i;
            sudo lxc-start -n node$i --daemon;
            "
        done
    else
        for i in $(seq $min $max); do
            sudo lxc-copy -n default -N "node$i"

            #### Distribute containers evenly over bridges
            lxc_node_config_file="/var/lib/lxc/node$i/config"
            bridge_num=$(( $i % $BRIDGE_COUNT ))
            lxc_ipv4_gateway_option="lxc.network.ipv4.gateway = 10.$bridge_num.3.1"
            lxc_ipv4_gateway="10.$bridge_num.3.1"
            static_ip=$(( $i + 10 ))
            if [[  $bridge_num != 0 ]]; then
                lxc_ipv4_option="lxc.network.ipv4 = 10.$bridge_num.3.$static_ip/24"
                lxc_link_option="lxc.network.link = lxcbr$bridge_num"
                echo "configuring node$i on bridge: lxcbr$bridge_num"
                sudo sed -i "s/lxc.network.link = .*/$lxc_link_option/g" $lxc_node_config_file
                if [[ -z "$( sudo cat $lxc_node_config_file | grep "$lxc_ipv4_option" )" ]]; then
                    echo "$lxc_ipv4_option" | sudo tee --append $lxc_node_config_file
                fi
                if [[ -z "$( sudo cat $lxc_node_config_file | grep "$lxc_ipv4_gateway_option" )" ]]; then
                    echo "$lxc_ipv4_gateway_option" | sudo tee --append $lxc_node_config_file
                fi
            else
                echo "configuring node$i on bridge: lxcbr0"
            fi

            #### Start container while making tap device
            sudo bash -c "
            sudo lxc-start -n node$i --daemon;
            sudo lxc-attach -n node$i -- bash -c 'sudo mkdir -p $IPOP_HOME; sudo mkdir /dev/net; sudo mknod /dev/net/tun c 10 200; sudo chmod 0666 /dev/net/tun';
            "
            sudo cp -r ./Controllers/controller/ "/var/lib/lxc/node$i/rootfs$IPOP_HOME"
            sudo cp ./ipop-tincan "/var/lib/lxc/node$i/rootfs$IPOP_HOME"
            sudo cp './node/node_config.sh' "/var/lib/lxc/node$i/rootfs$IPOP_HOME"
            sudo lxc-attach -n node$i -- bash -c "sudo chmod +x $IPOP_TINCAN; sudo chmod +x $IPOP_HOME/node_config.sh;"
            sudo lxc-attach -n node$i -- bash -c "sudo $IPOP_HOME/node_config.sh config $i GroupVPN $NET_IP4 $isvisual $topology_param containeruser password $lxc_ipv4_gateway"
            echo "Container node$i started."
            sudo ejabberdctl register "node$i" ejabberd password
            for j in $(seq $min $max); do
                if [ "$i" != "$j" ]; then
                    sudo ejabberdctl add_rosteritem "node$i" ejabberd "node$j" ejabberd "node$j" ipop both
                fi
            done
        done
    fi
    #sudo rm -r Controllers
}

function containers-start
{
    echo -e "\e[1;31mStarting containers... \e[0m"
    for i in $(seq $min $max); do
        sudo bash -c "sudo lxc-start -n node$i --daemon;"
        sudo bash -c "sudo lxc-attach -n node$i -- bash -c 'sudo mkdir /dev/net; sudo mknod /dev/net/tun c 10 200; sudo chmod 0666 /dev/net/tun';
            "

        echo "Container node$i started."
    done
}

function containers-del
{
    echo -e "\e[1;31mDeleting containers... \e[0m"
    for i in $(seq $min $max); do
        if [ $VPNMODE = "classic" ]; then
            for j in $(seq $min $max); do
                if [ "$i" != "$j" ]; then
                    sudo ejabberdctl delete_rosteritem "node$i" ejabberd "node$j" ejabberd
                fi
            done
            sudo ejabberdctl unregister "node$i" ejabberd
        fi
        sudo lxc-stop -n "node$i"
        sudo lxc-destroy -n "node$i"
    done
}

function containers-stop
{
    echo -e "\e[1;31mStopping containers... \e[0m"
    for i in $(seq $min $max); do
        sudo lxc-stop -n "node$i"
    done
}

function ipop-run
{
   container_to_run=$1

    if [ $VPNMODE = "switch" ]; then
        echo "Running ipop in switch-mode"
        sudo chmod 0666 /dev/net/tun
        mkdir -p logs/
        nohup sudo -b ./ipop-tincan &> logs/ctrl.log
        nohup sudo -b python -m controller.Controller -c ./ipop-config.json &> logs/tincan.log
    else
        if [[ ! ( -z "$container_to_run" ) ]]; then
            if [ "$container_to_run" = '#' ]; then
                for i in $(seq $min $max); do
                    echo "Running node$i"
                    sudo lxc-attach -n "node$i" -- nohup bash -c "cd $IPOP_HOME && ./node_config.sh run"
                    sleep 0.5
                done
            else
                echo "Running node$container_to_run"
                sudo lxc-attach -n "node$container_to_run" -- nohup bash -c "cd $IPOP_HOME && ./node_config.sh run"
            fi
        else
            echo -e "\e[1;31mEnter # To RUN all containers or Enter the container number.  (e.g. Enter 1 to start node1)\e[0m"
            read user_input
            if [ $user_input = '#' ]; then
                for i in $(seq $min $max); do
                    echo "Running node$i"
                    sudo lxc-attach -n "node$i" -- nohup bash -c "cd $IPOP_HOME && ./node_config.sh run"
                    sleep 0.5
                done
            else
                echo "Running node$user_input"
                sudo lxc-attach -n "node$user_input" -- nohup bash -c "cd $IPOP_HOME && ./node_config.sh run"
            fi
        fi
    fi
}

function ipop-kill
{
    container_to_kill=$1
    # kill IPOP tincan and controller
    if [ $VPNMODE = "switch" ]; then
        sudo ./node/node_config.sh kill
    else
        if [[ ! ( -z "$container_to_kill" ) ]]; then
          if [ "$container_to_kill" = '#' ]; then
            for i in $(seq $min $max); do
                sudo lxc-attach -n node$i -- bash -c "sudo $IPOP_HOME/node_config.sh kill"
            done
          else
            sudo lxc-attach -n node$container_to_kill -- bash -c "sudo $IPOP_HOME/node_config.sh kill"
          fi
      else
        echo -e "\e[1;31mEnter # To KILL all containers or Enter the container number.  (e.g. Enter 1 to stop node1)\e[0m"
        read user_input
        if [ $user_input = '#' ]; then
            for i in $(seq $min $max); do
                sudo lxc-attach -n node$i -- bash -c "sudo $IPOP_HOME/node_config.sh kill"
            done
        else
            sudo lxc-attach -n node$user_input -- bash -c "sudo $IPOP_HOME/node_config.sh kill"
        fi
      fi
    fi
}

function visualizer-start
{
    echo -e "\e[1;31mEnter visualizer github URL(default: $DEFAULT_VISUALIZER_REPO) \e[0m"
    read githuburl_visualizer
    if [ -z "$githuburl_visualizer" ]; then
        githuburl_visualizer=$DEFAULT_VISUALIZER_REPO
    fi
    git clone $githuburl_visualizer
    cd IPOPNetVisualizer

    echo -e "\e[1;31mDo you want to continue using master branch(Y/N):\e[0m"
    read user_input
    if [[ $user_input =~ [Nn](o)* ]]; then
       echo -e "Enter git repo branch name:"
       read github_branch
       git checkout $github_branch
    fi
    chmod +x setup_visualizer.sh
    ./setup_visualizer.sh
    cd ..
}

function visualizer-stop
{
    ps aux | grep "centVis.py" | awk '{print $2}' | xargs sudo kill -9
    ps aux | grep "aggr.py" | awk '{print $2}' | xargs sudo kill -9
    rm -rf ./IPOPNetVisualizer
}

function visualizer-status
{
    visualizer_aggr=$(ps aux | grep "[a]ggr")
    visualizer_cent=$(ps aux | grep "[c]entVis")

    if [ -n "$visualizer_aggr" -a -n "$visualizer_cent" ] ; then
           echo 'Visualizer is UP'
    else
           echo 'Visualizer is Down'
    fi
}

function ipop-status
{
    for i in $(seq $min $max); do
        container_status=$(sudo lxc-ls --fancy | grep "node$i" | awk '{ print $2 }')
        if [ "$container_status" = 'RUNNING' ] ; then
            ctrl_process_status=$(sudo lxc-attach -n "node$i" -- bash -c 'ps aux | grep "[c]ontroller.Controller"')
            tin_process_status=$(sudo lxc-attach -n "node$i" -- bash -c 'ps aux | grep "[i]pop-tincan"')

            if [ -n "$ctrl_process_status" ]; then
                    ctrl_real_status="Controller is UP"
            else
                    ctrl_real_status="Controller is DOWN"
            fi

            if [ -n "$tin_process_status" ]; then
                    echo "$ctrl_real_status && Tincan is UP on node$i"
            else
                    echo "$ctrl_real_status && Tincan is DOWN on node$i"
            fi

        else
                echo -e "node$i is not running"
        fi
    done
}


function logs
{
    if [ $VPNMODE = "classic" ]; then
        for i in $(seq $min $max); do
               mkdir -p logs/"node$i"
               sudo lxc-info -n "node$i" > logs/"node$i"/container_status.txt
               container_status=$(sudo lxc-ls --fancy | grep "node$i" | awk '{ print $2 }')
                node_rootfs="/var/lib/lxc/node$i/rootfs"
                node_logs="$node_rootfs/home/ubuntu/ipop/logs/."
                core_file="$node_rootfs/home/ubuntu/ipop/core"

               if [ -e $core_file ] ; then
                   sudo cp $core_file ".logs/node$i"
               fi

               if [ "$container_status" = 'RUNNING' ] ; then
                   sudo cp -r $node_logs "./logs/node$i"
               else
                    echo "node$i is not running"
               fi
        done
    fi
    echo "View ./logs/ to see ctrl and tincan logs"
}

function check-vpn-mode
{
    if [ -z $VPNMODE ] ; then
        echo -e "Select vpn mode to test: classic or switch"
        read VPNMODE
        echo "MODE $VPNMODE" >> $HELP_FILE
    fi
}

function configure-external-node
{
    username=$1
    hostname=$2
    xmpp_address=$3

    if [ -z "$username" ]; then
        read -p "Enter username: " username
    fi
    if [ -z "$hostname" ]; then
        read -p "Enter hostname: " hostname
    fi
    if [ -z "$xmpp_address" ]; then
        read -p "Enter xmpp server address: " xmpp_address
    fi

    scp ./external/external_setup.sh $username@$hostname:
    ssh "$username@$hostname" -t "sudo ./external_setup.sh $xmpp_address"
}

function ipop-tests
{
    sudo python ipoplxcutils/main.py
}

function mode
{
    action=$1
    current_vpn_mode=$(cat $HELP_FILE 2>/dev/null | grep MODE | awk '{print $2}')
    case $action in
        "change")
            if [[ "$current_vpn_mode" == "classic" ]]; then
                echo "Mode changed to switch."
                sed -i "s/MODE .*/MODE switch/g" $HELP_FILE
            else
                echo "Mode changed to classic."
                sed -i "s/MODE .*/MODE classic/g" $HELP_FILE
            fi
            ;;
        *)
            echo "Current mode: $current_vpn_mode"
            ;;
    esac
}

function mode-options
{
    echo -e "Options:\nshow -- view current mode\nchange -- switch between modes"
}

check-vpn-mode

$@

if [[ -z $@ ]] ; then
    line=($(options))
    cmd=${line[0]}
    case $cmd in
        ("configure")
            configure
        ;;
        ("containers-create")
            containers-create
        ;;
        ("containers-start")
            containers-start
        ;;
        ("containers-del")
            containers-del
        ;;
        ("containers-stop")
            containers-stop
        ;;
        ("ipop-run")
            ipop-run
        ;;
        ("ipop-kill")
            ipop-kill
        ;;
        ("ipop-status")
            ipop-status
        ;;
        ("quit")
            exit 0
        ;;
        ("visualizer-start")
            visualizer-start
        ;;
        ("visualizer-stop")
            visualizer-stop
        ;;
        ("visualizer-status")
            visualizer-status
        ;;
        ("ipop-tests")
            ipop-tests
        ;;
        ("logs")
            logs
        ;;
        ("mode")
        mode-options
        read -p "`echo $'> '`" action
        mode $action
        ;;
    esac
fi
