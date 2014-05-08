#!/usr/bin/env bash
sudo ./ipop-tincan &> tincan.log &
sleep 1
pid0=$!
pid1=`pgrep -P $pid0`
./svpn_controller.py -c config.json &> controller.log &
pid2=$!
sudo -u ubuntu touch kill.sh
sudo -u ubuntu cat > kill.sh << END
#!/usr/bin/env bash
sudo kill -9 $pid0
sudo kill -9 $pid1
sudo kill -9 $pid2
END
chmod +x kill.sh
