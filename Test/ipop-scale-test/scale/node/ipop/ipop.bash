#!/bin/bash

cd $(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

IPOP_TINCAN="./ipop-tincan"
IPOP_CONTROLLER="controller.Controller"
IPOP_CONFIG="./ipop-config.json"

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
            sudo $IPOP_TINCAN &> $LOG_TIN &
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
        ipop_id=$2
        vpn_type=$3
        serv_addr=$4
        fwdr_addr=$5
        fwdr_port=$6

        ### svpn configuration
        if [ "$vpn_type" == "svpn" ]; then

            # options reserved by scale-test
            CFx_xmpp_username="node${ipop_id}@ejabberd"
            CFx_xmpp_password="password"
            CFx_xmpp_host=$serv_addr
            CFx_xmpp_port='5222'
            CFx_vpn_type='SocialVPN'
            TincanSender_stun="${serv_addr}:3478"
            TincanSender_turn="{\"server\":\"$serv_addr:19302\",\"user\":\"node${ipop_id}\",\"pass\":\"password\"}"
            AddressMapper_ip4='172.31.0.100'
            CFx_ip4_mask='16'
            CentralVisualizer_name=$ipop_id
            CentralVisualizer_central_visualizer_addr=$fwdr_addr
            CentralVisualizer_central_visualizer_port=$fwdr_port

            CFx_tincan_logging='2'
            Logger_controller_logging='INFO'
            CentralVisualizer_enabled='true'
            CentralVisualizer_central_visualizer='true'
            Monitor_use_central_visualizer='true'

            # available options
            #TODO

            # create config file
            echo -e \
                "{"\
                "\n  \"CFx\": {"\
                "\n    \"xmpp_username\": \"$CFx_xmpp_username\","\
                "\n    \"xmpp_password\": \"$CFx_xmpp_password\","\
                "\n    \"xmpp_host\": \"$CFx_xmpp_host\","\
                "\n    \"xmpp_port\": $CFx_xmpp_port,"\
                "\n    \"tincan_logging\": 2,"\
                "\n    \"vpn_type\": \"$CFx_vpn_type\","\
                "\n    \"ip4_mask\": $CFx_ip4_mask,"\
                "\n    \"stat_report\": false"\
                "\n  },"\
                "\n  \"Logger\": {"\
                "\n    \"controller_logging\": \"INFO\""\
                "\n  },"\
                "\n  \"TincanSender\": {"\
                "\n    \"stun\": [\"$TincanSender_stun\"],"\
                "\n    \"turn\": [$TincanSender_turn],"\
                "\n    \"dependencies\": [\"Logger\"]"\
                "\n  },"\
                "\n  \"Monitor\": {"\
                "\n    \"trigger_con_wait_time\": 120,"\
                "\n    \"timer_interval\": 5,"\
                "\n    \"use_central_visualizer\": $Monitor_use_central_visualizer,"\
                "\n    \"dependencies\": [\"Logger\"]"\
                "\n  },"\
                "\n  \"Watchdog\": {"\
                "\n    \"timer_interval\": 10,"\
                "\n    \"dependencies\": [\"Logger\"]"\
                "\n  },"\
                "\n  \"AddressMapper\": {"\
                "\n    \"ip4\": \"$AddressMapper_ip4\","\
                "\n    \"dependencies\": [\"Logger\"]"\
                "\n  },"\
                "\n  \"BaseTopologyManager\": {"\
                "\n    \"sec\": true,"\
                "\n    \"multihop\": false,"\
                "\n    \"link_trimmer_wait_time\": 30,"\
                "\n    \"on-demand_connection\": false,"\
                "\n    \"on-demand_inactive_timeout\": 600,"\
                "\n    \"timer_interval\": 15,"\
                "\n    \"dependencies\": [\"Logger\"]"\
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
                "\n  \"StatReport\": {"\
                "\n    \"stat_report\": false,"\
                "\n    \"stat_server\": \"metrics.ipop-project.org\","\
                "\n    \"stat_server_port\": 8080,"\
                "\n    \"timer_interval\": 200,"\
                "\n    \"dependencies\": [\"Logger\"]"\
                "\n  },"\
                "\n  \"CentralVisualizer\": {"\
                "\n    \"enabled\": $CentralVisualizer_enabled,"\
                "\n    \"name\": \"$CentralVisualizer_name\","\
                "\n    \"central_visualizer_addr\": \"$CentralVisualizer_central_visualizer_addr\","\
                "\n    \"central_visualizer_port\": $CentralVisualizer_central_visualizer_port,"\
                "\n    \"dependencies\": [\"Logger\"]"\
                "\n  }"\
                "\n}"\
                > $IPOP_CONFIG

        ### gvpn configuration
        else
            # options reserved by scale-test
            CFx_xmpp_username="node${ipop_id}@ejabberd"
            CFx_xmpp_password="password"
            CFx_xmpp_host=$serv_addr
            CFx_xmpp_port='5222'
            CFx_vpn_type='GroupVPN'
            TincanSender_stun="${serv_addr}:3478"
            TincanSender_turn="{\"server\":\"$serv_addr:19302\",\"user\":\"node${ipop_id}\",\"pass\":\"password\"}"
            BaseTopologyManager_ip4='172.31.'$(($ipop_id / 256))'.'$(($ipop_id % 256))
            CFx_ip4_mask='16'
            CentralVisualizer_name=$ipop_id
            CentralVisualizer_central_visualizer_addr=$fwdr_addr
            CentralVisualizer_central_visualizer_port=$fwdr_port

            CFx_tincan_logging='2'
            Logger_controller_logging='INFO'
            CentralVisualizer_enabled='true'
            CentralVisualizer_central_visualizer='true'
            BaseTopologyManager_use_central_visualizer='true'

            # available options
            BaseTopologyManager_num_successors=$7
            BaseTopologyManager_num_chords=$8
            BaseTopologyManager_num_on_demand=$9
            BaseTopologyManager_num_inbound=${10}
            BaseTopologyManager_ttl_link_initial=${11}
            BaseTopologyManager_ttl_link_pulse=${12}
            BaseTopologyManager_ttl_chord=${13}
            BaseTopologyManager_ttl_on_demand=${14}
            BaseTopologyManager_threshold_on_demand=${15}

            BaseTopologyManager_interval_management='15'
            BaseTopologyManager_interval_central_visualizer='5'
            BaseTopologyManager_interval_ping='300'
            BaseTopologyManager_num_pings='5'

            # create config file
            echo -e \
                "{"\
                "\n  \"CFx\": {"\
                "\n    \"xmpp_username\": \"$CFx_xmpp_username\","\
                "\n    \"xmpp_password\": \"$CFx_xmpp_password\","\
                "\n    \"xmpp_host\": \"$CFx_xmpp_host\","\
                "\n    \"xmpp_port\": $CFx_xmpp_port,"\
                "\n    \"tincan_logging\": 2,"\
                "\n    \"vpn_type\": \"$CFx_vpn_type\","\
                "\n    \"ip4_mask\": $CFx_ip4_mask,"\
                "\n    \"stat_report\": false"\
                "\n  },"\
                "\n  \"Logger\": {"\
                "\n    \"controller_logging\": \"INFO\""\
                "\n  },"\
                "\n  \"TincanSender\": {"\
                "\n    \"switchmode\": 0,"\
                "\n    \"stun\": [\"$TincanSender_stun\"],"\
                "\n    \"turn\": [$TincanSender_turn],"\
                "\n    \"dependencies\": [\"Logger\"]"\
                "\n  },"\
                "\n  \"BaseTopologyManager\": {"\
                "\n    \"ip4\": \"$BaseTopologyManager_ip4\","\
                "\n    \"sec\": true,"\
                "\n    \"multihop\": false,"\
                "\n    \"num_successors\": $BaseTopologyManager_num_successors,"\
                "\n    \"num_chords\": $BaseTopologyManager_num_chords,"\
                "\n    \"num_on_demand\": $BaseTopologyManager_num_on_demand,"\
                "\n    \"num_inbound\": $BaseTopologyManager_num_inbound,"\
                "\n    \"ttl_link_initial\": $BaseTopologyManager_ttl_link_initial,"\
                "\n    \"ttl_link_pulse\": $BaseTopologyManager_ttl_link_pulse,"\
                "\n    \"ttl_chord\": $BaseTopologyManager_ttl_chord,"\
                "\n    \"ttl_on_demand\": $BaseTopologyManager_ttl_on_demand,"\
                "\n    \"threshold_on_demand\": $BaseTopologyManager_threshold_on_demand,"\
                "\n    \"timer_interval\": 1,"\
                "\n    \"interval_management\": $BaseTopologyManager_interval_management,"\
                "\n    \"use_central_visualizer\": $BaseTopologyManager_use_central_visualizer,"\
                "\n    \"interval_central_visualizer\": $BaseTopologyManager_interval_central_visualizer,"\
                "\n    \"num_pings\": $BaseTopologyManager_num_pings,"\
                "\n    \"interval_ping\": $BaseTopologyManager_interval_ping,"\
                "\n    \"dependencies\": [\"Logger\"]"\
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
                "\n  \"StatReport\": {"\
                "\n    \"stat_report\": false,"\
                "\n    \"stat_server\": \"metrics.ipop-project.org\","\
                "\n    \"stat_server_port\": 8080,"\
                "\n    \"timer_interval\": 200,"\
                "\n    \"dependencies\": [\"Logger\"]"\
                "\n  },"\
                "\n  \"CentralVisualizer\": {"\
                "\n    \"enabled\": $CentralVisualizer_enabled,"\
                "\n    \"name\": \"$CentralVisualizer_name\","\
                "\n    \"central_visualizer_addr\": \"$CentralVisualizer_central_visualizer_addr\","\
                "\n    \"central_visualizer_port\": $CentralVisualizer_central_visualizer_port,"\
                "\n    \"dependencies\": [\"Logger\"]"\
                "\n  }"\
                "\n}"\
                > $IPOP_CONFIG
        fi
        ;;
    (*)
        echo "invalid operation"
        ;;
esac

exit 0

