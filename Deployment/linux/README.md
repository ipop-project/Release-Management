<h1>IPOP Installer and IPOP for Ubuntu</h1>

Note: You need to have root access to run some of the following commands.

<h2>Installing 'wget' Package</h2>

In case 'wget' package is not installed, you need to install it first:

    sudo apt-get install wget

<h2>Using IPOP Installer</h2>

To use IPOP Installer, run this command:

    wget -O - http://raw.githubusercontent.com/ipop-project/Release-Management/master/Deployment/linux/installer | /bin/bash

The default installation directory will be `/opt/ipop` and you can use `ipop` executable script to control IPOP.

<h2>Using IPOP</h2>

First change current directory to the installation directory:

    cd /opt/ipop

Execute IPOP which is `ipop` executable script right in the installation directory with following parameters:

**Install IPOP:** (If you have already installed IPOP using IPOP Installer, you don't need to re-install it. So just skip this command.)

    ./ipop install

**Configure IPOP:**

    ./ipop config

**Start IPOP:**

    ./ipop start

**Get IPOP Node Status:**

    ./ipop status

**Stop IPOP:**

    ./ipop stop

<h2>Manual Configuration</h2>

If you ever need to change the configurations manually, the sample configuration files are located in `/opt/ipop/config`. IPOP reads the configurations from `/opt/ipop/config/config.json` which will automatically be created after running `./ipop config` and following the prompts. Keep in mind you need to stop IPOP and then start it again after changing the configurations.

<h2>Log Files</h2>

If anything went wrong while using IPOP, the log files are located in `/opt/ipop/log`.