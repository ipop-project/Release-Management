# Scale Test for the IPOP using Docker Containers

## Description
Creates a network testbed within a single host using Docker containers running IPOP.
Requires Python3, OpenvSwitch and Docker to be installed on host systems. User must also be added to the docker group. To run lots of containers consider reviewing and running update-limits.sh.  
All commands should be run from the Test directory.  
Edit the file ./template-config.json and add your XMPP server address and credentials, and optionally the network visualizer server IP address (if you are using network visualization).  

## Setting up a new host system
The setup script automates configuring a host system for running IPOP containers. Using setup.sh run the following commands. 
```
  ./setup.sh prereqs  # installs requried software
  ./setup.sh venv     # installs the python virtual environment
  ./setup netviz      # optional, needed if you are using network visualization
  ./source exp-venv/bin/activate
```

## Usage

### To get started:
```
  python testbed.py --help                    # List of available commands
  python testbed.py --clean                   # Removes all generated files
  python testbed.py --configure --range=1,11  # Configured the number of containers to run, eg., [1,11) = 10 containers
  python testbed.py --info                    # Information on the active testbed config
  python testbed.py --run                     # Starts the containers
  python testbed.py --end                     # Stops IPOP and terminates containers, eg., docker kill $(docker ps -aq)
```

### The testbed uses half closed intervals and supports simple partial ranges illustrated below.
```
  python testbed.py --clean
  python testbed.py --configure --range=1,11  # Configured the number of containers to run, eg., [1,11) = 10 containers
  python testbed.py --info
  python testbed.py -v --run --range=3,8      # Starts containers in range [3,8) == 3, 4, 5, 6, 7
  python testbed.py -v --end --range=3,5      # Stops conainers in range [3,5)
  python testbed.py -v --end --range=5,8      # Stops conainers in range [5,8)
```

### To run a ping test from all nodes to an IP address
```
  python testbed.py --clean
  python testbed.py --configure --range=1,11
  python testbed.py --run
  python testbed.py -v --ping=10.10.0.1
```
