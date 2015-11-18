#!/bin/sh
# this script runs SocialVPN inside Android 4.1 emulator
# this script is designed for Ubuntu 12.04 (64-bit)

HOST=$(hostname)

sudo aptitude update
sudo aptitude install -y libc6:i386 libncurses5:i386 libstdc++6:i386 tcpdump

wget -O android.tgz http://goo.gl/zrtLAR
wget -O android-sdk.tgz http://goo.gl/ZCPwF6
tar xzf android.tgz; tar xzf android-sdk.tgz

cd android-sdk

wget http://www.acis.ufl.edu/~ptony82/ipop/ipop-android_14.01.pre2.tgz
wget http://www.acis.ufl.edu/~ptony82/ipop/python27.tgz
wget http://github.com/ipop-project/ipop-scripts/raw/master/start_controller.sh
tar xzvf python27.tgz; tar xzvf ipop-android_14.01.pre2.tgz
mv start_controller.sh ipop-android_14.01.pre2

tools/emulator64-arm -avd svpn-android-4.1 -no-window -no-audio -no-skin &> log.txt &
sleep 60

platform-tools/adb shell rm -r data/ipop
platform-tools/adb shell mkdir data/ipop
platform-tools/adb shell mkdir data/ipop/python27

platform-tools/adb push ipop-android_14.01.pre2 /data/ipop
platform-tools/adb push python27 /data/ipop/python27
platform-tools/adb shell chmod 755 /data/ipop/ipop-tincan

sudo tcpdump -i eth0 -w svpn_$HOST.cap &> /dev/null &
platform-tools/adb shell "cd /data/ipop; ./ipop-tincan & sh start_controller.sh svpn_controller.py -c config.json &> log.txt &" &> log_$HOST.txt &

