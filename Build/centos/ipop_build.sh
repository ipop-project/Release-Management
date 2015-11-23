#!/bin/bash

sudo yum install java-1.7.0-openjdk-devel git subversion pkg-config make gcc gcc-c++ python
sudo yum install expat-devel gtk2-devel nss-devel openssl-devel
#sudo wget http://people.centos.org/tru/devtools-1.1/devtools-1.1.repo -P /etc/yum.repos.d
#sudo sh -c 'echo "enabled=1" >> /etc/yum.repos.d/devtools-1.1.repo'
#sudo yum install devtoolset-1.1

mkdir libjingle; 
cd libjingle
git clone --depth 1 https://chromium.googlesource.com/chromium/tools/depot_tools.git


#Set up environmental variables
export JAVA_HOME=/usr/lib/jvm/java
export PATH="$(pwd)/depot_tools:$PATH"
export GYP_DEFINES="use_openssl=1"
#sudo ln -s /usr/lib64/libpython2.6.so.1.0 /usr/lib/
scl enable devtoolset-1.1 bash

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
ninja -C out/Debug ipop-tincan


