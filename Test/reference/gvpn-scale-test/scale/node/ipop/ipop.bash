#!/bin/bash

cd $(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

IPOP_TINCAN="./ipop-tincan"
IPOP_CONTROLLER="controller.Controller"
IPOP_CONFIG="./controller/modules/gvpn-config.json"

LOG_TIN="./tin.log"
LOG_CTR="./ctr.log"

case $1 in

    ("run")
        pid=$(ps aux | grep -v grep | grep $IPOP_TINCAN | awk '{print $2}')
        if [ "$pid" != "" ]; then
            echo -e "IPOP is already running:\n$pid"
            exit -1
        fi

        # set executable flag
        sudo chmod +x $IPOP_TINCAN

		# random
		#sleep $(expr $RANDOM % 15)

        if [ "$2" == '--verbose' ]; then
            # run IPOP tincan
            sudo $IPOP_TINCAN &
            python -m $IPOP_CONTROLLER -c $IPOP_CONFIG &
        else
            # run IPOP tincan
            sudo $IPOP_TINCAN &> $LOG_TIN &
            python -m $IPOP_CONTROLLER -c $IPOP_CONFIG &> $LOG_CTR &
        fi
        ;;
    ("kill")
        # kill IPOP tincan and controller
        ps aux | grep -v grep | grep $IPOP_TINCAN | awk '{print $2}' | xargs sudo kill -9
        ps aux | grep -v grep | grep $IPOP_CONTROLLER | awk '{print $2}' | xargs sudo kill -9
        ;;
    ("config")
        # parse arguments
        xmpp_username=$2
        xmpp_password=$3
        xmpp_host=$4
        stun=$5
        turn=$6
        ipv4=$7
        ipv4_mask=$8

        central_visualizer=$9
        central_visualizer_ipv4=${10}
        central_visualizer_port=${11}
 
        num_successors=${12}
        num_chords=${13}
        num_on_demand=${14}
        num_inbound=${15}

        ttl_link_initial=${16}
        ttl_link_pulse=${17}

        ttl_chord=${18}
        ttl_on_demand=${19}

        threshold_on_demand=${20}

        interval_management=15
        interval_central_visualizer=5

        # create config file
        echo -e \
            "{"\
            "\n  \"CFx\": {"\
            "\n    \"xmpp_username\": \"$xmpp_username\","\
            "\n    \"xmpp_password\": \"$xmpp_password\","\
            "\n    \"xmpp_host\": \"$xmpp_host\","\
            "\n    \"tincan_logging\": 2,"\
            "\n    \"vpn_type\": \"GroupVPN\","\
            "\n    \"ip4_mask\": $ipv4_mask,"\
            "\n    \"stat_report\": false"\
            "\n  },"\
            "\n  \"Logger\": {"\
            "\n    \"controller_logging\": \"DEBUG\""\
            "\n  },"\
            "\n  \"TincanSender\": {"\
            "\n    \"switchmode\": 0,"\
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
            > $IPOP_CONFIG
        ;;
    (*)
        echo "invalid operation"
        ;;
esac

exit 0

