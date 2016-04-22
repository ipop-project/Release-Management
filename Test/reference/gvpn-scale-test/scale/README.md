#IPOP Network Scalability Test

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
node/ipop/ipop.bash      |End script used on a LXC container. Instructed by the node; configures/operates on IPOP sources.
node/ipop/<ipop sources\>|IPOP sources.

##Usage
Command        |Description
---------------|------------
accept         |Manually add node connections to the list of known hosts (SSH).
install        |Instruct nodes to receive contents of directory _node_. Nodes install lxc, ejabberd, and turnserver packages. Nodes prepare default LXC containers, one node establishes an ejabberd (XMPP/STUN) service and a turnserver (TURN) service.
init [size\]   |Instruct nodes to initialize platform. Nodes create distributed total of _size_ LXC containers, one node creates an ejabberd and turnserver account for all IPOP-nodes and define all links. NOTE: parameter _size_ is obtained from _scale.cfg_ if not provided.
exit           |Instruct nodes to clear all LXC containers, one node removes all ejabberd and turnserver accounts and undefines all links.
source         |Instruct nodes to receive contents of directory _node_. Nodes then copy sources to the LXC containers.
config <args\> |Instruct nodes to create configuration files for each IPOP-node using arguments _args_.
forward <port\>|Instruct one node to run a forwarding program using port _port_.
run [list/all] |Instruct nodes to run the _list_ of, or _all_, IPOP-nodes.
kill [list/all]|Instruct nodes to run the _list_ of, or _all_, IPOP-nodes.
quit           |Quit this program.

NOTE: "Nodes" are defined as the physical/virtual computers in this testbed. "IPOP-nodes" are instances of the IPOP software running in a LXC container (one IPOP-node per LXC container).

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
The platform is ready, enter the following commands as necessary to update sources, create configuration files, or run or kill IPOP-nodes.
_source_
_config <args\>_
_run [list/all]_
_kill [list/all]_
7. Clearing the platform
To clear the platform, enter _exit_. This returns the script procedures to just after the _install_. To re-initialize the platform, enter _init [size\]_.