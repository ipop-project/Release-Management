# Scale Test for the IPOP using Docker Containers

### Description
Creates a network testbed within a single host using Docker containers running IPOP.
Requires Python3, OpenvSwitch and Docker to be installed on host systems. User my also be added to the docker group. See setup.sh.

### Usage
[1] To get started:
```
  python3 testbed.py --clean
  python3 testbed.py --configure --range1,11
  python3 testbed.py --info
  python3 testbed.py --run
  python3 testbed.py --end
```

[2] Also supports simple partial ranges
```
  python3 testbed.py --clean
  python3 testbed.py --configure --range1,11
  python3 testbed.py --info
  python3 testbed.py -v --run --range=3,8
  python3 testbed.py -v --end --range=3,5
  python3 testbed.py -v --end --range=5,8 
```

[3] Ping test from all nodes to an IP address
```
  python3 testbed.py --clean
  python3 testbed.py --configure --range1,11
  python3 testbed.py --run
  python3 testbed.py -v --ping=10.10.0.1
```
