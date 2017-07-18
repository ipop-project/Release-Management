#!/bin/bash

cd $(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
IPOP_CONFIG="./ipop-config.json"
case $1 in
    ("config")
        # create config file
        ipop_id=$2
        vpn_type=$3
        serv_addr=$4
        # options reserved by scale-test
        CFx_xmpp_username="node${ipop_id}@ejabberd"
        CFx_xmpp_password="password"
        CFx_xmpp_host=$serv_addr
        CFx_xmpp_port='5222'
        BaseTopologyManager_ip4='172.31.'$(($ipop_id / 256))'.'$(($ipop_id % 256))
        CFx_ip4_mask='16'
        CentralVisualizer_name=$ipop_id
        CentralVisualizer_central_visualizer_addr=$serv_addr":8080/insertdata"
        isVisulizerEnabled=$5
        # available options
        BaseTopologyManager_num_successors=$6
        BaseTopologyManager_num_chords=$7
        BaseTopologyManager_num_on_demand=$8
        BaseTopologyManager_num_inbound=$9
        turn_host=$serv_addr
        turn_user=$10
        turn_password=$11
        echo -e \
            "{"\
                "\n  \"CFx\": {"\
                "\n    \"Model\": \"$vpn_type\""\
                "\n  },"\
                "\n  \"Logger\": {"\
                "\n    \"LogLevel\": \"DEBUG\""\
                "\n  },"\
		"\n  \"VirtualNetworkInitializer\": {"\
		"\n    \"Vnets\": [{"\
                "\n       \"IP4\": \"$BaseTopologyManager_ip4\","\
                "\n       \"IP4Prefix\": $CFx_ip4_mask, "\
                "\n       \"XMPPModuleName\": \"XmppClient\", "\
                "\n       \"TapName\": \"ipop_tap0\","\
                "\n       \"Description\": \"Ethernet Device\","\
                "\n       \"IgnoredNetInterfaces\": [\"ipop_tap0\", \"ipop_tap1\", \"Bluetooth Network Connection\", \"VMware Network Adapter VMnet1\", \"VMware Network Adapter VMnet2\"],"\
                "\n       \"L2TunnellingEnabled\": 1"\
                "\n     }],"\
		"\n     \"Stun\": [\"stun.l.google.com:19302\"],"\
                "\n     \"Turn\": [{"\
                "\n        \"Address\": \"$turn_host:19302\","\
                "\n        \"User\": \"$turn_user\","\
                "\n        \"Password\": \"$turn_password\""\
                "\n     }]"\
                "\n  },"\
                "\n  \"XmppClient\": {"\
		"\n    \"XmppDetails\": [ "\
		"\n      { "\
                "\n        \"Enabled\": true,"\
                "\n        \"Username\": \"$CFx_xmpp_username\","\
                "\n        \"Password\": \"$CFx_xmpp_password\","\
                "\n        \"AddressHost\": \"$CFx_xmpp_host\","\
                "\n        \"Port\": \"$CFx_xmpp_port\","\
                "\n        \"TapName\": \"ipop_tap0\","\
                "\n        \"AuthenticationMethod\": \"password\","\
                "\n        \"AcceptUntrustedServer\": true"\
		"\n      } "\
		"\n    ] "\
                "\n  },"\
                "\n  \"BaseTopologyManager\": {"\
                "\n    \"NumberOfSuccessors\": $BaseTopologyManager_num_successors,"\
                "\n    \"NumberOfChords\": $BaseTopologyManager_num_chords,"\
                "\n    \"NumberOfOnDemand\": $BaseTopologyManager_num_on_demand,"\
                "\n    \"NumberOfInbound\": $BaseTopologyManager_num_inbound"\
                "\n  },"\
                "\n  \"OverlayVisualizer\": {"\
                "\n    \"Enabled\": $isVisulizerEnabled,"\
                "\n    \"WebServiceAddress\": \"$CentralVisualizer_central_visualizer_addr\","\
		"\n    \"NodeName\": \"node$ipop_id\""\
                "\n  }"\
                "\n}"\
        > $IPOP_CONFIG
        ;;
    ("kill")
            ps aux | grep "ipop-tincan" | awk '{print $2}' | xargs sudo kill -9
            ps aux | grep "controller.Controller" | awk '{print $2}' | xargs sudo kill -9
        ;;
esac
