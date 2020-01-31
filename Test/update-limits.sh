#!/bin/bash

cp /etc/sysctl.conf /etc/sysctl.conf.`date +%F-%H%M%S`
echo "kernel.keys.maxkeys=2000" >> /etc/sysctl.conf
echo "fs.inotify.max_queued_events=1048576" >> /etc/sysctl.conf
echo "fs.inotify.max_user_instances=1048576" >> /etc/sysctl.conf
echo "fs.inotify.max_user_watches=1048576" >> /etc/sysctl.conf
echo "vm.max_map_count=262144" >> /etc/sysctl.conf
echo "net.ipv4.neigh.default.gc_thresh3=8192" >> /etc/sysctl.conf

cp /etc/security/limits.conf /etc/security/limits.conf.`date +%F-%H%M%S`
echo "*       soft    nofile  1048576" >> /etc/security/limits.conf
echo "*       hard    nofile  1048576" >> /etc/security/limits.conf
echo "root    soft    nofile  1048576" >> /etc/security/limits.conf
echo "root    hard    nofile  1048576" >> /etc/security/limits.conf
echo "*       soft    memlock unlimited" >> /etc/security/limits.conf
echo "*       hard    memlock unlimited" >> /etc/security/limits.conf
