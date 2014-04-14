#!/bin/sh

while true
do
  ips=$(echo '{"m":"get_state"}' | nc -q 1 -u 127.0.0.1 5800 | \
        grep ip4 | grep -v _ip4 | awk '{print $3}' | cut -d \" -f 2)
  for i in $ips
  do 
      ping -c 10 -w 10 -q $i >> pings.txt
  done
  sleep 30
done
