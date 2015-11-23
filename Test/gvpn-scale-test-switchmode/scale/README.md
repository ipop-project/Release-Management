#IPOP Network Scalability Test of switchmode

##Description
This tool was created to assist in scalable IPOP networks. This tool is designed as a hierarchical set of bash scripts and operations are distributed/parallelized where possible, utilizing a variable number of physical/virtual nodes (CloudLab, Amazon EC2, etc.) and a variable number of LXC containers to achieve a scalable testbed. The produces are fully automated for productivity (see _Usage_ below).

##Source
In scale/:

File |Description
-----|-----------
scale.bash               |Main script used on a local machine. Instructs nodes.
scale.cfg                |Configuration file.
visualizer.py            |Parse debug messages from IPOP-nodes for visualizing IPOP network.
node/node.bash           |Intermediate script used on a node. Instructed by the local machine; instructs LXC containers (IPOP-nodes).
node/dbg_forwarder.py    |This program is a service that converts debug UDP datagrams from the LXC containers into a single TCP session. This is a solution for testers whose local computer does not have a public IPv4 address.

##Usage
Command         |Description
----------------|------------
accept          |Manually add node connections to the list of known hosts (SSH).
install         |Instruct nodes to receive contents of directory _node_. Nodes install lxc, ejabberd, and turnserver packages. Nodes prepare default LXC containers, one node establishes an ejabberd (XMPP/STUN) service and a turnserver (TURN) service.
init [size\]    |Instruct nodes to initialize platform. Nodes create distributed total of _size_ LXC containers, one node creates an ejabberd and turnserver account for all IPOP-nodes and define all links. Changing lxcbr ip address. NOTE: parameter _size_ is obtained from _scale.cfg_ if not provided.
exit            |Instruct nodes to clear all LXC containers, one node removes all ejabberd and turnserver accounts and undefines all links.
config <args\>  |Instruct IPOP-nodes to create configuration files.
run [list/all]  |Instruct IPOP-nodes to run ipop-tincan and controller. Attach ipop tap device to lxcbr0.
kill [list/all] |Instruct IPOP-nodes to kill ipop-tincan and controller.
start [list/all]|Instruct IPOP-nodes to start _list_ of, or _all_, lxcs.
stop [list/all] |Instruct IPOP-nodes to stop _list_ of, or _all_, lxcs.
forward <port\> |Instruct one node to run a forwarding program using port _port_.
mem <vnode_id>  |Get the memory utilization information of tincan in the specific IPOP-node.
iperf <args\>   |Test the network throughput between two lxc. Enter "iperf help" for detailed usage in scale.bash.
ping <args\>    |Test the network delay between two lxc. Enter "ping help" for detailed usage in scale.bash.
quit            |Quit this program.

NOTE: "IPOP-nodes" are defined as the physical/virtual computers in this testbed.

##Example
1. Go to CloudLab.us
2. Create a profile and run it as an experiment
Allocate any number of nodes.
For Disk Image, enter: "urn:publicid:IDN+emulab.net+image+emulab-ops:UBUNTU15-04-64-STD".
Ensure that at least on node is allocated a public IPv4 address - this node will host the XMPP/STUN/TURN services.
Since XMPP/STUN/TURN services are needed, ensure that one node is allocated a public IPv4 address.
Optionally, if a separate node will run the forwarding program, ensure that another node is also allocated a public IPv4 address.
3. Copy connections entries into _scale.cfg_. Example (100 IPOP-nodes instantiated on 3 nodes with 1 also hosting XMPP/STUN/TURN services and 1 also forwarding):
NODE user@cloudlab_instance.A
NODE user@cloudlab_instance.B
NODE user@cloudlab_instance.C
SERVER user@cloudlab_instance.A
FORWARDER user@cloudlab_instance.B
SIZE 100
4. Run _scalabe.bash_
5. Initialize the platform
To prepare the platform, enter the following commands in this order.
_accept_
_install_
_init_
6. Configuring and IPOP network simulation
The platform is ready, enter the following commands as necessary to create configuration files, run or kill IPOP-tincan and controller, and start or stop lxc.
_config <args\>_
_run [list/all]_
_start [list/all]_
7. Testing the IPOP network
Enter the following commands to get the memory utilization of tincan on each node, test the network throughput and delay.
_mem <physical node_id>_
_ping <args\>_
_iperf <args\>_
8. Clearing the platform
To clear the platform, enter _exit_. This returns the script procedures to just after the _install_. To re-initialize the platform, enter _init [size\]_.
