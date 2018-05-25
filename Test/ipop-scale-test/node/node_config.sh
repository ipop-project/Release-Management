#!/bin/bash

cd $(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
IPOP_CONFIG="./ipop-config.json"
case $1 in
    ("config")
        # create config file
        ipop_id=$2
        sample_overlay_id="ABCDEF0"
        ipop_model=$3
        serv_addr=$4
        # options reserved by scale-test
        CFx_xmpp_username="node${ipop_id}@ejabberd"
        CFx_xmpp_password="password"
        CFx_xmpp_host=$serv_addr
        CFx_xmpp_port='5222'
        Ip4='10.254.'$(($ipop_id / 256))'.'$(($ipop_id % 256))
        CFx_ip4_mask=16
        CFx_mtu4=1500
        Visualizer_CollectorService_addr=$serv_addr":5000"
        isVisulizerEnabled=$5
        # available options
        TURN_host="$serv_addr:3478"
        echo -en \
            "{"\
                "\n  \"CFx\": {"\
                "\n    \"Model\": \"$ipop_model\","\
                "\n    \"Overlays\": [\"$sample_overlay_id\"]"\
                "\n  },"\
                "\n  \"Logger\": {"\
                "\n    \"Enabled\": true,"\
                "\n    \"LogLevel\": \"DEBUG\""\
                "\n  },"\
                "\n  \"TincanInterface\": {"\
                "\n    \"Enabled\": true"\
                "\n  },"\
                "\n  \"Signal\": {"\
                "\n    \"Enabled\": true,"\
                "\n    \"Overlays\": {"\
                "\n      \"$sample_overlay_id\": { "\
                "\n        \"Username\": \"$CFx_xmpp_username\","\
                "\n        \"Password\": \"$CFx_xmpp_password\","\
                "\n        \"HostAddress\": \"$CFx_xmpp_host\","\
                "\n        \"Port\": \"$CFx_xmpp_port\","\
                "\n        \"AuthenticationMethod\": \"PASSWORD\","\
                "\n        \"AcceptUntrustedServer\": true"\
                "\n        } "\
                "\n      } "\
                "\n  },"\
                "\n  \"Topology\": {"\
                "\n    \"Enabled\": true,"\
                "\n    \"Overlays\": {"\
                "\n      \"$sample_overlay_id\": { "\
                "\n        \"Name\": \"$CFx_xmpp_username\","\
                "\n        \"Description\": \"$CFx_xmpp_password\","\
                "\n        \"EnableIPMapping\": false,"\
                "\n        \"EncryptionEnabled\": true"\
                "\n      } "\
                "\n    } "\
                "\n  },"\
                "\n  \"LinkManager\": {"\
                "\n    \"Enabled\": true,"\
                "\n     \"Stun\": [\"stun.l.google.com:19302\"],"\
                "\n     \"Turn\": [{"\
                "\n        \"Address\": \"$TURN_host\","\
                "\n        \"User\": \"user\","\
                "\n        \"Password\": \"password\""\
                "\n     }],"\
                "\n    \"Overlays\": {"\
                "\n      \"$sample_overlay_id\": { "\
                "\n        \"Type\": \"$ipop_model\","\
        > $IPOP_CONFIG;

        if [ "$ipop_model" == "VNET" ]; then
            echo -en \
                "\n        \"IP4\": \"$Ip4\","\
                "\n        \"IP4PrefixLen\": $CFx_ip4_mask,"\
                "\n        \"MTU4\": $CFx_mtu4,"\
            >> $IPOP_CONFIG;
        fi

        echo -en \
                "\n        \"TapName\": \"ipop_tap0\","\
                "\n        \"IgnoredNetInterfaces\": [\"ipop_tap0\"]"\
                "\n      } "\
                "\n    } "\
                "\n  },"\
                "\n  \"Icc\": {"\
                "\n    \"Enabled\": true"\
                "\n  },"\
        >> $IPOP_CONFIG;

        if [ "$ipop_model" == "VNET" ]; then
            echo -en \
                "\n  \"Broadcaster\": {"\
                "\n    \"Enabled\": true"\
                "\n  },"\
            >> $IPOP_CONFIG;
        fi

        echo -en \
            "\n  \"OverlayVisualizer\": {"\
            "\n    \"Enabled\": $isVisulizerEnabled,"\
            "\n    \"WebServiceAddress\": \"$Visualizer_CollectorService_addr\","\
            "\n    \"NodeName\": \"node$ipop_id\""\
            "\n  }"\
            "\n}"\
            >> $IPOP_CONFIG
        ;;
    ("run")
        mkdir -p logs
        sudo chmod 0666 /dev/net/tun
        nohup ./ipop-tincan &> ./logs/tin_start.log &
        nohup python3 -m controller.Controller -c ./ipop-config.json &> ./logs/ctrl_start.log &
        ;;
    ("kill")
        ps aux | grep "ipop-tincan" | awk '{print $2}' | xargs sudo kill -s SIGINT
        ps aux | grep "controller.Controller" | awk '{print $2}' | xargs sudo kill -s SIGINT
        ;;
esac
