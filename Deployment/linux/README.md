<h1>IPOP Installer and IPOP for Ubuntu and CentOS</h1>

Note: You need to have root access to run some of the following commands.

<h2>Installing 'wget' and 'unzip' Packages</h2>

In case 'wget' and 'unzip' packagea are not installed, you need to install them first:

**In Ubuntu:**

    sudo apt-get install wget unzip

**In CentOS:**

    su yum install wget unzip

<h2>Using IPOP Installer</h2>

To use IPOP Installer, run this command:

    wget -O - https://raw.githubusercontent.com/ipop-project/Release-Management/master/Deployment/linux/installer | /bin/bash

The default installation directory will be `/opt/ipop` and you can use IPOP to control the IPOP.

<h2>Using IPOP</h2>

Execute IPOP which is `ipop` executable script right in the installation directory, which is `/opt/ipop` by default, with following parameters:

**Install IPOP:** (If you have already installed IPOP using IPOP Installer, you don't need to re-install it. So just skip this.)

    ./ipop install

**Configure IPOP:**

    ./ipop config

**Start IPOP:**

    ./ipop start

**Get IPOP Node Status:**

    ./ipop status

**Stop IPOP:**

    ./ipop stop
