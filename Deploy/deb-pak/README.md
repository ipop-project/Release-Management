# IPOP-DEBIAN PACKAGE

The IPOP-VPN Debian package installs IPOP as a systemd service and is supported in Ubuntu 18.04 and Raspberry Pi Raspbian OS. Use the following procedure to create a new installer package.
1. Clone the `Release-Management` repo and use `Release-Management/Deploy/deb-pak` as your base directory.
2. Copy the `ipop-tincan` executable, and the `controller` folder into `ipop-vpn/opt/ipop-vpn`.
3. Copy `config.json`, the template or completed file, into `ipop-vpn/etc/opt/ipop-vpn`.
4. Execute `./deb-gen` to create the `ipop-vpn.deb` installer package.

By default, the following files and directories are created:
1. `/opt/ipop-vpn/ipop-tincan`
2. `/opt/ipop-vpn/controller/`
3. `/etc/opt/ipop-vpn/config.json`
4. `/etc/systemd/system`
5. `/var/logs/ipop-vpn/tincan_log`
6. `/var/logs/ipop-vpn/ctrl.log`

The installer has dependencies on, and will install `python3`, `python3-pip`, `iproute2`, `openvswitch-switch`, `bridge-utils`.  
To install IPOP-VPN invoke `sudo -H apt install -y <path/to/installer>/ipop-vpn.deb`.  
After installation but before starting IPOP, complete `config.json` by adding the XMPP credentials, setting the IP address, and applying other configurations as needed.  
Then start IPOP using `sudo systemctl start ipop`.  
Additionally, use `systemctl` to start/stop/restart/status ipop.

IPOP is configured to be started automatically on reboot.
