<h1>IPOP Installer and IPOP Assistant for Ubuntu and CentOS</h1>

Note: You need to have root access to run some of the following commands.

<h2>Installing wget Package</h2>

In case there is no "wget" package installed, you need to install it first:

**In Ubuntu:**

    sudo apt-get install wget

**In CentOS:**

    su yum install wget

<h2>Using IPOP Installer</h2>

To use IPOP Installer, run this command:

    wget -O - https://raw.githubusercontent.com/ipop-project/Release-Management/master/Deployment/linux/installer | /bin/bash

The default installation directory will be `/opt/ipop` and you can use IPOP Assistant to control the IPOP.

<h2>Using IPOP Assistant</h2>

Execute IPOP Assistant which is `assistant` executable script right in the installation directory with following parameters:

**Install IPOP:** (If you have already installed IPOP using IPOP Installer, you don't need to re-install it.)

    ./assistant install

**Configure IPOP:**

    ./assistant config

**Start IPOP:**

    ./assistant start

**Get IPOP Node Status:**

    ./assistant status

**Stop IPOP:**

    ./assistant stop
