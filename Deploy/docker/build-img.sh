#!/bin/bash

DKR=`command -v docker`
[ -z "$DKR" ] && (echo "Cannot locate docker executable"; exit 1)

prj=ipopproject
ver=1.0
ipopdkrfl=./ipop-vpn.Dockerfile
fixbadproxy=./setup/99fixbadproxy
setupreqs=./setup/setup-base.sh
debpak=./setup/ipop-vpn_20.2.20_amd64.deb
[ -f $fixbadproxy ] || { echo ERROR: $fixbadproxy not found; exit 1; }
[ -f $ipopdkrfl ] || { echo ERROR: $ipopdkrfl not found; exit 1; }
[ -f $setupreqs ] || { echo ERROR: $setupreqs not found; exit 1; }
[ -f $debpak ] || { echo ERROR: $debpak not found; exit 1; }
ipop=`$DKR images -q $prj/ipop-vpn:$ver`
#[ $ipop ] && ($DKR rmi $ipop)
#ipop=`$DKR images -q $prj/ipop-vpn:$ver`
#[ $ipop ] && (echo failed to remove existing IPOP-VPN docker image, it may be running)

$DKR build -f $ipopdkrfl -t $prj/ipop-vpn:$ver .
