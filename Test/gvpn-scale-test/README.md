# Scale Test for the IPOP Structured P2P GroupVPN Controller

### Description

This project is composed of scripts for automating the preparation and simulation of a testbed for scalable testing of the IPOP network using structured-p2p-gvpn-controller, which has been pushed upstream [1].

[1] ```https://github.com/ipop-project/controllers```

[2] ```http://ipop-project.org/ or https://github.com/ipop-project```


### Usage

#### Obtaining the source code

```
git clone https://github.com/ipop-project/controllers.git
cd controllers/; git checkout devel; cd -

git clone https://github.com/ssabogal/ipop-gvpn-scale-test.git
cd ipop-gvpn-scale-test/
mv ../controllers/controller scale/node/ipop/
```

Note: A precompiled binary for **IPOP-Tincan** is available in ```scale/node/ipop```. The latest IPOP-Tincan can be obtained by downloading the latest archive from the releases or by building from source [2].

#### Preparing physical nodes (using CloudLab)

##### Pre-defined profiles

Use any of the following pre-defined profiles:

```
IPOP_SCALE_TEST_1_VIVID
IPOP_SCALE_TEST_2_VIVID
IPOP_SCALE_TEST_5_VIVID
```

##### Create a profile

Create a profile, with at least one node and each node containing the following properties:

* Node Type ```raw-pc```

* Hardware Type ```C220M4```

* Disk Image ```Other...``` with URN ```urn:publicid:IDN+emulab.net+image+emulab-ops:UBUNTU15-04-64-STD```

* Check the ```Publicly Routable IP``` option

##### Create an experiment

Note: ensure that the host's SSH keys are applied to the CloudLab account.

Instantiate this profile as to create an experiment.

#### Using the automated test script

Open the ```List View``` tab to view the connections. Copy the connections (of the form ```<username>@<hostname>```) into ```scale/scale.cfg``` as ```NODE```, ```SERVER```, or ```FORWARDER```. Also specify the ```SIZE``` (the number of IPOP instances)

Run the bash script:
```bash scale/scale.bash```

Enter the following commands (see the ```README.md``` in ```scale/``` for information about what these commands do):
```
accept    # enter 'yes' if prompted
install
init
source
config <num_successors> <num_chords> <num_on_demand> <num_inbound> <ttl_link_initial> <ttl_link_pulse> <ttl_chord> <ttl_on_demand> <threshold_on_demand>
run all
```
Example: ```config 2 3 2 8 60 30 180 60 128``` defines the BaseTopologyManager to support:

* about 2 successors
* up to 3 chords
* up to 2 on-demand links
* about 8 in-bound links
* initializing links have a time-to-live of 60 seconds before they are trimmed
* established links have a time-to-live of 30 seconds before they are trimmed
* chords have a time-to-live of 180 seconds before they may be replaced
* on-demand links have a time-to-live of 60 seconds before they undergoes a threshold test
* on-demand links have a threshold of 128 transmitted bytes per second before they are trimmed

To view the IPOP network using the available visualizer, enter ```forward <port>``` within the bash script.

#### Using the visualizer:

Note: the visualizer depends on TKinter, use ```pacman -S tk``` (in Archlinux) or ```apt-get install python3-tk``` (in Ubuntu/Debian).

In scale.bash:

```forward <forwarder port>```

In a separate terminal:

```python3 scale/visualizer.py tcp <forwarder ipv4> <forwarder port> <SIZE> <GUI window size (length)>```
