#!/bin/bash

# Ubuntu 15.04 URN: urn:publicid:IDN+emulab.net+image+emulab-ops:UBUNTU15-04-64-STD

IPOP_CONTROLLER_COMMIT="v16.01.0"
IPOP_TINCAN_VER="v16.01.0"

CONF_FILE="./scale.cfg"
NODE_PATH="./node"
NODE_NODE_SCRIPT='./node/node.bash'

NODES=()
NR_NODES=0
SERVER=''
FORWARDER=''
SIZE=0

FORWARDER_PROGRAM='visualizer.py'

cd $(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

function prompt()
{
    [[ "$1" != '' ]]
    read -p '> ' prompt_ret
    echo $prompt_ret
}

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
        ("CONTROLLER")
            IPOP_CONTROLLER_COMMIT=$arg;;
        ("TINCAN")
            IPOP_TINCAN_VER=$arg;;
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
            IPOP_CONTROLLER_REPO="https://github.com/ipop-project/controllers"
            IPOP_TINCAN_URL="https://github.com/ipop-project/Downloads/releases/download/$IPOP_TINCAN_VER/ipop-${IPOP_TINCAN_VER}_ubuntu.tar.gz"

            mkdir tmp.sources; cd tmp.sources

            # obtain controller sources
            git clone $IPOP_CONTROLLER_REPO
            cd controllers
            git checkout $IPOP_CONTROLLER_COMMIT
            cd ..
            cp -r controllers/controller ../node/ipop/

            # obtain ipop-tincan binary
            wget $IPOP_TINCAN_URL
            tar xf ipop-${IPOP_TINCAN_VER}_ubuntu.tar.gz
            cp ipop-tincan ../node/ipop/

            cd ..; #rm -rf tmp.sources
            ;;
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
            done
            wait
            rm node.tar.gz
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
            rm node.tar.gz
            ;;
        ("config")
            vpn_type=(${args[0]})
            serv_addr=$(echo "$SERVER" | cut -d "@" -f2)
            fwdr_addr=$(echo "$FORWARDER" | cut -d "@" -f2)
            fwdr_port='50101'
            params=(${args[@]:1})

            # vnodes create IPOP config files
            for node in ${NODES[@]}; do
                ssh $node "bash $NODE_NODE_SCRIPT config $vpn_type $serv_addr $fwdr_addr $fwdr_port ${params[@]}" &
            done
            wait
            ;;
        ("forward")
            forwarder_addr=$(echo "$FORWARDER" | cut -d "@" -f2)
            forwarder_port='50101'
            forwarded_port=(${args[0]})

            # launch forwarder
            ssh $FORWARDER "bash $NODE_NODE_SCRIPT forward $forwarder_addr $forwarder_port $forwarded_port &" &
            echo "connect visualizer to $forwarder_addr $forwarded_port"
            ;;
        ("visualize")
            forwarder_addr=$(echo "$FORWARDER" | cut -d "@" -f2)
            forwarded_port=(${args[0]})
            vpn_type=(${args[1]})

            python3 $FORWARDER_PROGRAM tcp $forwarder_addr $forwarded_port $vpn_type &
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
            echo '    download                       : download controller sources and ipop-tincan binary'
            echo '    accept                         : manually enable connections'
            echo '    install                        : install/prepare resources'
            echo '    init      [size]               : initialize platform'
            echo '    restart                        : restart services'
            echo '    exit                           : clear platform'
            echo '    source                         : upload sources'
            echo '    config    <args>               : create IPOP config file'
            echo '    forward   <gvpn|svpn> <port>   : run forwarder in background'
            echo '    visualize <port> <gvpn|svpn>   : run forwarder in background'
            echo ''
            echo '  IPOP network simulation:'
            echo '    run       [list|all]           : run list|all nodes'
            echo '    kill      [list|all]           : kill list|all nodes'
            echo ''
            echo '  utility:'
            echo '    quit                           : quit program'
            ;;

    esac

done

