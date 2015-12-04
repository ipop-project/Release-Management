#!/bin/bash

# Ubuntu 15.04 URN: urn:publicid:IDN+emulab.net+image+emulab-ops:UBUNTU15-04-64-STD

DOWNLOAD="https://github.com/ipop-project/Downloads/releases/download"
RELEASEDIR="15.11.0.RC1"
RELEASENAME="ipop-v15.11.0-RC1_Ubuntu"

cd $(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

function prompt()
{
    [[ "$1" != '' ]]
    read -p '> ' prompt_ret
    echo $prompt_ret
}

CONF_FILE="./scale.cfg"
NODE_PATH="./node"
NODE_NODE_SCRIPT='./node/node.bash'

NODES=()
NR_NODES=0
SERVER=''
FORWARDER=''
SIZE=0

# parse config file
while read line; do
    opt=$(echo $line | awk '{print $1}')
    arg=$(echo $line | awk '{print $2}')

    case $opt in
        ("NODE")
            NODES+=($arg);;
        ("SERVER")
            SERVER=$arg;;
        ("FORWARDER")
            FORWARDER=$arg;;
        ("SIZE")
            SIZE=$arg;;
    esac
done < $CONF_FILE
NR_NODES=${#NODES[@]}

# main loop
while true; do

    line=($(prompt))
    cmd=${line[0]}
    args=(${line[@]:1})

    case $cmd in

        ("download")
            echo "downloading latest release from github"
            wget $DOWNLOAD/$RELEASEDIR/$RELEASENAME.tar.gz
            tar zxvf $RELEASENAME.tar.gz
            cp -r $RELEASENAME/controller node/ipop/
            rm -rf $RELEASENAME*
        ("accept")
            echo "enter 'yes' to add a node to the list of known hosts"
            for node in ${NODES[@]}; do
                ssh $node "echo 'accepted connection: $node'"
            done
            ;;
        ("install")
            # compress local sources; transfer sources to each node; nodes install
            tar -zcvf node.tar.gz $NODE_PATH
            for node in ${NODES[@]}; do
                bash -c "
                    echo 'put node.tar.gz' | sftp $node;
                    ssh $node 'tar xf node.tar.gz; bash $NODE_NODE_SCRIPT install';
                " &
                tmp='\*    soft    core    unlimited';
                ssh $node "sudo bash -c 'echo "$tmp" >> /etc/security/limits.conf; ulimit -c unlimited'";
            done
            wait
            ;;
        ("init")
            if [ "${args[0]}" != "" ]; then
                SIZE=${args[0]}
                sed -i "s/SIZE.*/SIZE $SIZE/g" $CONF_FILE
            fi

            # initialize containers (vnodes)
            for i in $(seq 0 $(($NR_NODES-1))); do
                min=$(($i * ($SIZE / $NR_NODES)))
                max=$(((($i+1) * ($SIZE / $NR_NODES)) - 1))

                ssh ${NODES[$i]} "bash $NODE_NODE_SCRIPT init-containers $min $max" &
            done
            wait

            # initialize ejabberd
            ssh $SERVER "bash $NODE_NODE_SCRIPT init-server $SIZE"

            ;;
        ("restart")
            ssh $SERVER "bash $NODE_NODE_SCRIPT restart-server"
            ;;
        ("exit")
            # remove containers
            for node in ${NODES[@]}; do
                 ssh $node "bash $NODE_NODE_SCRIPT exit-containers" &
            done
            wait

            # remove ejabberd
            ssh $SERVER "bash $NODE_NODE_SCRIPT exit-server"
            ;;
        ("source")
            # compress local sources; transfer sources to each node; nodes update souces of each vnode
            tar -zcvf node.tar.gz $NODE_PATH
            for node in ${NODES[@]}; do
                bash -c "
                    echo 'put node.tar.gz' | sftp $node;
                    ssh $node 'tar xf node.tar.gz; bash $NODE_NODE_SCRIPT source';
                " &
            done
            wait
            ;;
        ("config")
            # obtain ipv4 address of ejabberd server
            server_node_ethd=$(ssh $SERVER ifconfig | grep eth | awk '{print $1}' | head -n 1)
            server_node_ipv4=$(ssh $SERVER ifconfig $server_node_ethd | grep "inet addr" | awk -F: '{print $2}' | awk '{print $1}')

            # obtain ipv4 address/port of forwarder
            forwarder_node_ethd=$(ssh $FORWARDER ifconfig | grep eth | awk '{print $1}' | head -n 1)
            forwarder_node_ipv4=$(ssh $FORWARDER ifconfig $forwarder_node_ethd | grep "inet addr" | awk -F: '{print $2}' | awk '{print $1}')
            forwarder_node_port=51234

            # vnodes create IPOP config files
            for node in ${NODES[@]}; do
                # prepare arguments
                xmpp_host=$server_node_ipv4
                stun="$server_node_ipv4:3478"
                turn="$server_node_ipv4:19302"
                central_visualizer='true'
                central_visualizer_ipv4=$forwarder_node_ipv4
                central_visualizer_port=$forwarder_node_port

                ssh $node "bash $NODE_NODE_SCRIPT config $xmpp_host $stun $turn $central_visualizer $central_visualizer_ipv4 $central_visualizer_port ${args[@]}" &
            done
            wait
            ;;
        ("forward")
            # obtain ipv4 address/port of forwarder
            forwarder_node_ethd=$(ssh $FORWARDER ifconfig | grep eth | awk '{print $1}' | head -n 1)
            forwarder_node_ipv4=$(ssh $FORWARDER ifconfig $forwarder_node_ethd | grep "inet addr" | awk -F: '{print $2}' | awk '{print $1}')
            forwarder_node_port=51234
            forward_port=${args[0]}

            ssh $FORWARDER "bash $NODE_NODE_SCRIPT forward $forwarder_node_ipv4 $forwarder_node_port $forward_port &" &

            echo "connect visualizer to $forwarder_node_ipv4 $forward_port"
            ;;
        ("run")
            # check if 'all' is present
            for i in ${args[@]}; do
                if [ "$i" == 'all' ]; then
                    args=($(seq 0 $(($SIZE-1))))
                fi
            done

            # create list of vnodes for each node
            node_list=()
            for i in ${args[@]}; do
                index=$(($i / ($SIZE / $NR_NODES)))
                node_list[$index]="${node_list[$index]} $i"
            done

            # nodes run list of vnodes
            for i in $(seq 0 $(($NR_NODES - 1))); do
                ssh ${NODES[$i]} "bash $NODE_NODE_SCRIPT run '${node_list[$i]}' &" &
            done
            ;;
        ("kill")
            # check if 'all' is present
            for i in ${args[@]}; do
                if [ "$i" == 'all' ]; then
                    args=($(seq 0 $(($SIZE-1))))
                fi
            done

            # create list of vnodes for each node
            node_list=()
            for i in ${args[@]}; do
                index=$(($i / ($SIZE / $NR_NODES)))
                node_list[$index]="${node_list[$index]} $i"
            done

            # nodes kill list of vnodes
            for i in $(seq 0 $(($NR_NODES - 1))); do
                ssh ${NODES[$i]} "bash $NODE_NODE_SCRIPT kill '${node_list[$i]}' &" &
            done
            ;;
        ("quit")
            exit 0
            ;;
        (*)
            echo 'usage:'
            echo '  platform management:'
            echo '    download           : download the latest release from github'
            echo '    accept             : manually enable connections'
            echo '    install            : install/prepare resources'
            echo '    init    [size]     : initialize platform'
            echo '    restart            : restart services'
            echo '    exit               : clear platform'
            echo '    source             : upload sources'
            echo '    config  <args>     : create IPOP config file'
            echo '    forward <port>     : run forwarder in background'
            echo ''
            echo '  IPOP network simulation:'
            echo '    run     [list|all] : run list|all nodes'
            echo '    kill    [list|all] : kill list|all nodes'
            echo ''
            echo '  utility:'
            echo '    quit               : quit program'
            ;;

    esac

done

