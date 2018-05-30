# IPOP-DEBIAN PACKAGE


1) After generating the Tincan binary, the generated ipop-tincan binary file should be copied into the "ipop-vpn/opt/ipop-vpn" directory.

2) Also, the "controllers" subdirectory under the "Controllers" directory should also be copied into the "ipop-vpn/opt/ipop-vpn" directory.

3) The config file should be copied into the "ipop-vpn/etc/ipop-vpn" directory. The config file should be properly completed before/after copying into the directory.

4) Make sure the current directory is "ipop-deb". And then run the following command to build the ipop-vpn debain package:

		dpkg-deb --build ipop-vpn

5) To install the ipop-vpn software, run the following command in the same directory:

		sudo apt-get install ./ipop-vpn

This command places the binary files in the /opt/ipop-vpn and the config file in /etc/ipop-vpn directories. The ipop.service file is placed in the /etc/systemd/system directory.

6) To activate the ipop-systemd daemon service (only for the first time), run the following commands:

		sudo systemctl daemon-reload
		sudo systemctl enable ipop
		sudo systemctl start ipop

The ipop service will now run as a daemon in the background. The ipop service will start automatically as a daemon everytime the system is booted.

7) Everytime the binary files or the config file has been changed, the steps from 1-5 should be repeated. And then instead of step 6, do the following command:

		sudo systemctl restart ipop

