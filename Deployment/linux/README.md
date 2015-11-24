Running the IPOP Installer


In case there is no wget package installed on the linux container, you need to install it first:


In Ubuntu:

sudo apt-get install wget


In CentOS:

su yum install wget


To use the IPOP Installer, run this command:

wget -O - http://vdaneshmand.com/installer | /bin/bash
