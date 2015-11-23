#!/bin/bash

sudo apt-get update
sudo apt-get install default-jdk pkg-config git subversion make gcc g++ python
sudo apt-get install libexpat1-dev libgtk2.0-dev libnss3-dev libssl-dev 

mkdir libjingle; cd libjingle
git clone --depth 1 https://chromium.googlesource.com/chromium/tools/depot_tools.git

#Set up environmental variables
export JAVA_HOME=/usr/lib/jvm/default-java
export PATH="$(pwd)/depot_tools:$PATH"
export GYP_DEFINES="use_openssl=1"

#Configure gclient to download libjingle code
gclient config --name=trunk http://webrtc.googlecode.com/svn/branches/3.52

#Download libjingle and dependencies (this may take a while). Ignore eror messages about pkg-config looking for gobject-2.0 gthread-2.0 gtk+-2.0
gclient sync --force

#Download ipop-tincan from github.com/ipop-project
cd trunk/talk; mkdir ipop-project; cd ipop-project
git clone --depth 1 https://github.com/ipop-project/ipop-tap.git
git clone --depth 1 https://github.com/ipop-project/ipop-tincan.git

#Build ipop-tincan for Linux
#The generated binary is located at out/Release/ipop-tincan or out/Debug/ipop-tincan
cd ../../
rm -f DEPS all.gyp talk/libjingle.gyp talk/ipop-tincan.gyp
cp talk/ipop-project/ipop-tincan/build/ipop-tincan.gyp talk/
cp talk/ipop-project/ipop-tincan/build/libjingle.gyp talk/
cp talk/ipop-project/ipop-tincan/build/all.gyp .
cp talk/ipop-project/ipop-tincan/build/DEPS .

gclient sync --force
gclient runhooks --force
ninja -C out/Release ipop-tincan
#ninja -C out/Debug ipop-tincan


