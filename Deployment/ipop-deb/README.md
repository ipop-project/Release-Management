# IPOP-DEBIAN PACKAGE

The IPOP-VPN Debian package installs IPOP as a systemd service and is supported in Ubuntu 18 and Raspbian OS. Use the following procedure to create a new installer package.
1. Clone the `Release-Management` repo and use `Release-Management/Deployment/ipop-deb` as your base directory.
2. Copy the `ipop-tincan` executable, and the `controller` folder into `ipop-vpn/opt/ipop-vpn`.
3. Copy `config.json`, the template or completed file, into `ipop-vpn/etc/opt/ipop-vpn`.
4. Update `/ipop-vpn/DEBIAN/control` with the appropriate architecture.   
5. Invoke the command `dpkg-deb --build ipop-vpn` to create the "ipo-vpn.deb" installer package

By default, the following files and directories are created:
1. `/opt/ipop-vpn/ipop-tincan`
2. `/opt/ipop-vpn/controller/`
3. `/etc/opt/ipop-vpn/config.json`
4. `/etc/systemd/system`
5. `/var/logs/ipop-vpn/tincan_log`
6. `/var/logs/ipop-vpn/ctrl.log`

The installer has dependencies on, and will install `python3`, `python3-pip`, `iproute2`, `openvswitch-switch`, `bridge-utils`.  
To install IPOP-VPN invoke `sudo -H atp isntall -y <path/to/installer>/ipop-vpn.deb`.  
After installation but before starting IPOP, complete `config.json` by adding the XMPP credentials.  
Next start IPOP using `sudo systemctl start ipop`.  
Additionally, use `systectl` to start/stop/restart/status ipop.

IPOP is configured to be started automatically on reboot.

## Known Issues
The following issues are pending resolution:  
1. Controller termination routines are not being invoked.  
2. Active ports at service shutdown are not removed from the OVS bridge and the bridge will have to be manually removed/pruned of old ports before restart. Use the cmd `sudo ovs-vsctl del-br ipopbr0` to delete the bridge and remove it port configuration.   
3. Removing the IPOP-VPN does not delete the `/opt/ipop-vpn/` directory as post installed files are still present.
