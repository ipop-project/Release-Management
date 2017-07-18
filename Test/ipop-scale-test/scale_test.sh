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
    visualizer-start               : install and start up visualizer
    visualizer-stop                : stop all visualizer related processes
    logs                           : aggregate ipop logs under ./logs
    '
}


function options
{
    read -p "$(help) `echo $'\n> '`" user_input
    echo $user_input
}

function configure
{
    # if argument is true mongodb and ejabberd won't be installed
    is_external=$1

    #Python dependencies for visualizer and ipop python tests
    sudo apt-get install -y python python-pip python-lxc

    pip install --upgrade pip
    pip install pymongo

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
    if [ $VPNMODE = "switch-mode" ]; then
        pip install sleekxmpp pystun psutil
    else
        sudo chroot /var/lib/lxc/default/rootfs apt-get -y install 'python-pip'
        sudo chroot /var/lib/lxc/default/rootfs pip install 'sleekxmpp' pystun psutil
    fi

    echo 'lxc.cgroup.devices.allow = c 10:200 rwm' | sudo tee --append $DEFAULT_LXC_CONFIG

    if [[ ! ( "$is_external" = true ) ]]; then
        # Install turnserver
        sudo apt-get install -y libconfuse0 turnserver
        echo "containeruser:password:ipopvpn.org:authorized" | sudo tee --append $TURN_USERS
        # use IP aliasing to bind turnserver to this ipv4 address
        sudo ifconfig $NET_DEV:0 $NET_IP4 up
        # prepare turnserver config file
        sudo cp $TURN_CONFIG $TURN_ROOT_CONFIG
        sudo sed -i "s/listen_address = .*/listen_address = { \"$NET_IP4\" }/g" $TURN_ROOT_CONFIG
        turnserver -c $TURN_ROOT_CONFIG
    fi

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

    # function parameters
    container_count=$1
    controller_repo_url_arg=$2
    tincan_repo_url_arg=$3
    visualizer_arg=$4
    is_external=$5

    if [ -z "$container_count" ]; then
        echo -e "No of containers to be created::"
        read max
        min=1
        echo -e "MIN $min\nMAX $max\nNR_VNODES $max" > $HELP_FILE
        echo $MODELINE >> $HELP_FILE
    else
        max=$container_count
        min=1
        echo -e "MIN 1\nMAX $max\nNR_VNODES $max" > $HELP_FILE
        echo $MODELINE >> $HELP_FILE
    fi

    if [ -z "$controller_repo_url_arg" ]; then
        echo "Downloading executable and code"
        # Check if IPOP controller executables already exists
        if [ -e $CONTROLLER ]; then
            echo "Controller modules already present in the current path.Do you want to continue with container creation (T/F).."
            read user_input
            if [ $user_input = 'F' ]; then
                echo -e "\e[1;31mEnter IPOP Controller github URL(default: $DEFAULT_CONTROLLERS_REPO) \e[0m"
                read githuburl_ctrl
                if [ -z "$githuburl_ctrl" ]; then
                    githuburl_ctrl=$DEFAULT_CONTROLLERS_REPO
                fi
                git clone $githuburl_ctrl
                echo -e "Do you want to continue using master branch(Y/N):"
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
            echo -e "\e[1;31mEnter IPOP Controller github URL(default: $DEFAULT_CONTROLLERS_REPO) \e[0m"
            read githuburl_ctrl
            if [ -z "$githuburl_ctrl" ]; then
                githuburl_ctrl=$DEFAULT_CONTROLLERS_REPO
            fi
            git clone $githuburl_ctrl
            echo -e "Do you want to continue using master branch(Y/N):"
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
        git clone $controller_repo_url_arg
    fi

    if [ -z "$tincan_repo_url_arg" ]; then
        # Check whether Tincan executables exists in the current path
        if [ -e $TINCAN ]; then
            echo "Tincan binary present, aborting build script execution!!!"
        else
            echo "***************Building Tincan binary***************"
            echo -e "\e[1;31mEnter github URL for Tincan (default: $DEFAULT_TINCAN_REPO) \e[0m"
            read github_tincan
            if [ -z "$github_tincan" ] ; then
                github_tincan=$DEFAULT_TINCAN_REPO
            fi

            git clone $github_tincan
            echo -e "Do you want to continue using master branch(Y/N):"
            read user_input
            if [ $user_input = 'N' ]; then
                echo -e "Enter git repo branch name:"
                read github_branch
                cd Tincan
                git checkout $github_branch
                cd ..
            fi
            cd ./Tincan/trunk/build/
            make
            cd ../../..
            cp ./Tincan/trunk/out/release/x64/ipop-tincan .
        fi
    else
        git clone $tincan_repo_url_arg
        cd ./Tincan/trunk/build
        make
        cd ../../..
        cp ./Tincan/trunk/out/release/x64/ipop-tincan .
    fi

    if [ -z "$visualizer_arg" ]; then
        echo -e "\e[1;31mEnable Visulaization (T/F): \e[0m"
        read visualizer
        if [ $visualizer = 'T' ]; then
            isvisual=true
        else
            isvisual=false
        fi
    else
        if [ "$visualizer_arg" = 'T' ]; then
            isvisual=true
        else
            isvisual=false
        fi
    fi

    if [[ ! ( "$is_external" = true ) ]]; then
        echo -e "\e[1;31Do you want to set default IPOP network configuration(Y/N): \e[0m"
        read user_input

        if [ $user_input = 'Y' ]; then
            topology_param="4 4 0 4"
        else
            topology_param=""
            echo -e "\e[1;31m Enter No of Successor Links: \e[0m"
            read user_input
            topology_param="$topology_param $user_input"
            echo -e "\e[1;31m Enter Max No of Chords Links: \e[0m"
            read user_input
            topology_param="$topology_param $user_input"
            echo -e "\e[1;31m Enter Max No of Ondemand Links: \e[0m"
            read user_input
            topology_param="$topology_param $user_input"
            echo -e "\e[1;31m Enter Max No of Inbound Links: \e[0m"
            read user_input
            topology_param="$topology_param $user_input"
        fi
    else
       topology_param="1 0 0 3"
    fi

    echo "VPN MODE: $VPNMODE"

    if [[ "$VPNMODE" = "switch-mode" ]]; then
        sudo mkdir -p /dev/net
        sudo rm /dev/net/tun
        sudo mknod /dev/net/tun c 10 200
        sudo chmod 0666 /dev/net/tun
        sudo chmod +x ./ipop-tincan
        sudo chmod +x ./node/node_config.sh
        sudo cp -r ./Controllers/controller/ ./

        if [[ ! ( "$is_external" = true ) ]]; then
            sudo ./node/node_config.sh config 1 GroupVPN $NET_IP4 $isvisual $topology_param
            sudo ejabberdctl register "node1" ejabberd password
        else
            sudo ./node/node_config.sh config 2 GroupVPN $NET_IP4 $isvisual $topology_param
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
            sudo bash -c "
            lxc-copy -n default -N node$i;
            sudo lxc-start -n node$i --daemon;
            sudo lxc-attach -n node$i -- bash -c 'sudo mkdir -p $IPOP_HOME; sudo mkdir /dev/net; sudo mknod /dev/net/tun c 10 200; sudo chmod 0666 /dev/net/tun';
            "
            sudo cp -r ./Controllers/controller/ "/var/lib/lxc/node$i/rootfs$IPOP_HOME"
            sudo cp ./ipop-tincan "/var/lib/lxc/node$i/rootfs$IPOP_HOME"
            sudo cp './node/node_config.sh' "/var/lib/lxc/node$i/rootfs$IPOP_HOME"
            sudo lxc-attach -n node$i -- bash -c "sudo chmod +x $IPOP_TINCAN; sudo chmod +x $IPOP_HOME/node_config.sh;"
            sudo lxc-attach -n node$i -- bash -c "sudo $IPOP_HOME/node_config.sh config $i GroupVPN $NET_IP4 $isvisual $topology_param containeruser password"
            echo "Container node$i started."
            sudo ejabberdctl register "node$i" ejabberd password
            for j in $(seq $min $max); do
                if [ "$i" != "$j" ]; then
                    sudo ejabberdctl add_rosteritem "node$i" ejabberd "node$j" ejabberd "node$j" ipop both
                fi
            done
        done
    fi
    sudo rm -r Controllers
    sudo rm -r Tincan
}

function containers-start
{
    echo -e "\e[1;31mStarting containers.... \e[0m"
    for i in $(seq $min $max); do
        sudo bash -c "sudo lxc-start -n node$i --daemon;"
        echo "Container node$i started."
    done
}

function containers-del
{
    echo -e "\e[1;31mContainer deletion inprogress .... \e[0m"
    for i in $(seq $min $max); do
        if [ $VPNMODE = "classic-mode" ]; then
            for j in $(seq $min $max); do
                if [ "$i" != "$j" ]; then
                    sudo ejabberdctl delete_rosteritem "node$i" ejabberd "node$j" ejabberd
                    sudo ejabberdctl unregister "node$i" ejabberd
                fi
            done
        fi
        sudo lxc-stop -n "node$i"
        sudo lxc-destroy -n "node$i"
    done
}

function containers-stop
{
    echo -e "\e[1;31mStopping container... \e[0m"
    for i in $(seq $min $max); do
        sudo lxc-stop -n "node$i"
    done
}

function ipop-run
{
   container_to_run=$1

    mkdir -p logs/

    if [ $VPNMODE = "switch-mode" ]; then
        echo "Running ipop in switchmode"
        sudo chmod 0666 /dev/net/tun
        nohup sudo -b ./ipop-tincan &> logs/ctrl.log
        nohup sudo -b python -m controller.Controller -c ./ipop-config.json &> logs/tincan.log
    else
        if [[ ! ( -z "$container_to_run" ) ]]; then
            if [ "$container_to_run" = '#' ]; then
                for i in $(seq $min $max); do
                    echo "Running node$i"
                    sudo lxc-attach -n "node$i" -- bash -c 'sudo chmod 0666 /dev/net/tun'
                    sudo lxc-attach -n "node$i" -- nohup bash -c 'cd /home/ubuntu/ipop/ && ./ipop-tincan &'
                    sudo lxc-attach -n "node$i" -- nohup bash -c 'cd /home/ubuntu/ipop/ && python -m controller.Controller -c ./ipop-config.json &'
                done
            else
                echo "Running node$container_to_run"
                sudo lxc-attach -n "node$container_to_run" -- bash -c 'sudo chmod 0666 /dev/net/tun'
                sudo lxc-attach -n "node$container_to_run" -- nohup bash -c 'cd /home/ubuntu/ipop/ && ./ipop-tincan &'
                sudo lxc-attach -n "node$container_to_run" -- nohup bash -c 'cd /home/ubuntu/ipop/ && python -m controller.Controller -c ./ipop-config.json &'
            fi
        else
            echo -e "\e[1;31mEnter # To RUN all containers or Enter the container number.  (e.g. Enter 1 to start node1)\e[0m"
            read user_input
            if [ $user_input = '#' ]; then
                for i in $(seq $min $max); do
                    echo "Running node$i"
                    sudo lxc-attach -n "node$i" -- bash -c 'sudo chmod 0666 /dev/net/tun'
                    sudo lxc-attach -n "node$i" -- nohup bash -c 'cd /home/ubuntu/ipop/ && ./ipop-tincan &'
                    sudo lxc-attach -n "node$i" -- nohup bash -c 'cd /home/ubuntu/ipop/ && python -m controller.Controller -c ./ipop-config.json &'
                done
            else
                echo "Running node$user_input"
                sudo lxc-attach -n "node$user_input" -- bash -c 'sudo chmod 0666 /dev/net/tun'
                sudo lxc-attach -n "node$user_input" -- nohup bash -c 'cd /home/ubuntu/ipop/ && ./ipop-tincan &'
                sudo lxc-attach -n "node$user_input" -- nohup bash -c 'cd /home/ubuntu/ipop/ && python -m controller.Controller -c ./ipop-config.json &'
            fi
        fi
    fi
}

function ipop-kill
{
    container_to_kill=$1
    # kill IPOP tincan and controller
    if [ $VPNMODE = "switch-mode" ]; then
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
    if [ -z "$githuburl_visualizer"]; then
        githuburl_visualizer=$DEFAULT_VISUALIZER_REPO
    fi
    git clone $githuburl_visualizer
    cd IPOPNetVisualizer
    echo -e "Do you want to continue using master branch(Y/N):"
    read user_input
    if [ $user_input = 'N' ]; then
       echo -e "Enter git repo branch name:"
       read github_branch
       git checkout $github_branch
    fi
    # Install visualizer deps in virtual env
    python -m pip install virtualenv
    python -m virtualenv venv
    source ./venv/bin/activate
    python -m pip install -r requirements.txt
    nohup python aggr.py &> aggr.log &
    sleep 5s
    nohup python centVis.py &> centVis.log &
    cd ..
}

function visualizer-stop
{
    ps aux | grep "centVis.py" | awk '{print $2}' | xargs sudo kill -9
    ps aux | grep "aggr.py" | awk '{print $2}' | xargs sudo kill -9
    rm -rf ./IPOPNetVisualizer
}

function logs
{
    if [ $VPNMODE = "classic-mode" ]; then
        controller_log='/home/ubuntu/ipop/logs/ctrl.log'
        tincan_log='/home/ubuntu/ipop/logs/tincan.log_0'
        for i in $(seq $min $max); do
               mkdir -p logs/"node$i"
               sudo lxc-info -n "node$i" > logs/"node$i"/container_status.txt
               container_status=$(sudo lxc-ls --fancy | grep "node$i" | awk '{ print $2 }')

               if [ "$container_status" = 'RUNNING' ] ; then
                    ctrl_process_status=$(sudo lxc-attach -n "node$i" -- bash -c 'ps aux | grep "[c]ontroller.Controller"')
                    tin_process_status=$(sudo lxc-attach -n "node$i" -- bash -c 'ps aux | grep "[i]pop-tincan"')
                    ctrl_log_status=$(sudo lxc-attach -n "node$i" -- bash -c "[ -f $controller_log ] && echo 'FOUND' || echo 'NOT FOUND'")
                    tin_log_status=$(sudo lxc-attach -n "node$i" -- bash -c "[ -f $tincan_log ] && echo 'FOUND' || echo 'NOT FOUND'")

                    if [ -n "$ctrl_process_status" ]; then
                            echo "Controller is UP on node$i"
                    else
                            echo "Controller is DOWN on node$i"
                    fi

                    if [ -n "$tin_process_status" ]; then
                            echo "Tincan is UP on node$i"
                    else
                            echo "Tincan is DOWN on node$i"
                    fi

                    if [ "$ctrl_log_status" = 'FOUND' ] ; then
                            echo "Captured node$i controller log "
                            sudo lxc-attach -n "node$i" -- bash -c "cat $controller_log" > logs/"node$i"/ctrl.log
                    else
                            echo 'Controller log file not found'
                    fi

                    if [ "$tin_log_status" = 'FOUND' ] ; then
                            echo "Captured node$i tincan log "
                            sudo lxc-attach -n "node$i" -- bash -c "cat $tincan_log" > logs/"node$i"/tincan.log
                    else
                            echo "Tincan log file for node$i not found"
                    fi
               else
                    echo -e "node$i is not running"
               fi
        done
    fi

    echo -e "View $(pwd)/logs/ to see ctrl and tincan logs"
    visualizer_aggr=$(ps aux | grep "[a]ggr")
    visualizer_cent=$(ps aux | grep "[c]entVis")

    if [ -n "$visualizer_aggr" -a -n "$visualizer_cent" ] ; then
           echo 'Visualizer is UP'
    else
           echo 'Visualizer is Down'
    fi
}

function check-vpn-mode
{
    if [ -z $VPNMODE ] ; then
        echo -e "Select vpn mode to test:\nclassic-mode or switch-mode"
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
        ("quit")
            exit 0
        ;;
        ("visualizer-start")
            visualizer-start
        ;;
        ("visualizer-stop")
            visualizer-stop
        ;;
        ("ipop-tests")
            ipop-tests
        ;;
        ("logs")
            logs
        ;;
    esac
fi
