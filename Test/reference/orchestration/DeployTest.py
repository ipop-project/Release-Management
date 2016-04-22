#!/usr/bin/env python

import json
import subprocess
import unittest
import time

instance_count = 3
ipop_download_link = "https://github.com/ipop-project/downloads/releases/"+\
                     "download/14.07.1.rc2/ipop-14.07.1.rc2-x86_ubuntu.tar.gz"
ipop_dir = "ipop-14.07.1.rc2-x86_ubuntu" 

run_script = """
#!/usr/bin/env bash
cd /home/ubuntu
sudo ./ipop-tincan &> tincan.log &
#Make sure the UDP socket is created at tincan first
#If O/S overloaded, there is possibility of controller
#starting socket connection first.
netstat -lun | grep -q "::1:5800"
asdf=\$?
while [ 1 -eq \$asdf ]
do
  netstat -lun | grep -q "::1:5800"
  asdf=\$?
  sleep 1
done
./svpn_controller.py -c config.json &> controller.log &
"""

autostart = """
#!/bin/sh -e
/home/ubuntu/run.sh
exit 0
EOF
"""


class TestInstall(unittest.TestCase):
    def setUp(self):
        #Install LXC and XMPP
        subprocess.call(["sudo", "apt-get", "update"])
        subprocess.call(["sudo", "apt-get", "-y", "upgrade"])
        subprocess.call(["sudo", "apt-get", "-y", "install", "ejabberd", "lxc"])
        subprocess.call(["wget", "-q", "-O", "ejabberd.cfg",\
                         "http://goo.gl/iObOjl"])
        subprocess.call(["sudo", "cp", "ejabberd.cfg", "/etc/ejabberd/"])
        subprocess.call(["sudo", "service", "ejabberd", "restart"])

    def test_xmpp(self):
        ret = subprocess.call(["dpkg-query", "-l", "ejabberd"])
        self.assertTrue(ret == 0)
        
    def test_lxc(self):
        ret = subprocess.call(["dpkg-query", "-l", "lxc"])
        self.assertTrue(ret == 0)

class TestLxcCreate(unittest.TestCase):

    def setUp(self):
        #Create LXC instance
        subprocess.call(["sudo", "lxc-create", "-t", "ubuntu", "-n", "ipop0"])

        #Install python and tap device in instance
        subprocess.call(["sudo", "chroot", "/var/lib/lxc/ipop0/rootfs",\
                         "apt-get", "update"])
        subprocess.call(["sudo", "chroot", "/var/lib/lxc/ipop0/rootfs",\
                         "apt-get", "install", "-y", "python-keyring"])
        subprocess.call(["sudo", "chroot", "/var/lib/lxc/ipop0/rootfs",\
                         "mkdir", "/dev/net"])
        subprocess.call(["sudo", "chroot", "/var/lib/lxc/ipop0/rootfs",\
                         "mknod", "/dev/net/tun", "c", "10", "200"])
        subprocess.call(["sudo", "chroot", "/var/lib/lxc/ipop0/rootfs",\
                         "chmod", "666", "/dev/net/tun"])

        #Clone ipop0 to multiple instances
        for i in range(1, instance_count):
            subprocess.call(["sudo", "lxc-clone", "-o", "ipop0", "-n",\
                             "ipop"+str(i)])

    def test_instance(self):
        p = subprocess.Popen(["sudo", "lxc-ls"], stdout=subprocess.PIPE)
        out = p.communicate()[0].split("\n")
        for i in range(0, instance_count):
            self.assertTrue("ipop"+str(i) in out)


class TestSocialVPN(unittest.TestCase):
    #def setUp(self):
    @classmethod
    def setUpClass(cls):
        subprocess.call(["wget", "-O", "ipop.tar.gz", ipop_download_link])
        subprocess.call(["tar", "-xzvf", "ipop.tar.gz"])
        config = {}
        config["xmpp_host"] = "10.0.3.1"
        config["ip4"] = "172.31.0.100"

        idu = subprocess.Popen(["id", "-un"], stdout=subprocess.PIPE)
        user, _ = idu.communicate()
        idg = subprocess.Popen(["id", "-gn"], stdout=subprocess.PIPE)
        group, _ = idg.communicate()
        user_group = user.split("\n")[0] + ":" + group.split("\n")[0]

        arch = subprocess.Popen(["uname", "--hardware-platform"],\
                                 stdout=subprocess.PIPE)
        platform = arch.communicate()[0]
        if platform.split("\n")[0] == "x86_64":
            subprocess.call(["sudo", "cp", ipop_dir+"/ipop-tincan-x86_64",\
              ipop_dir+"/ipop-tincan"])
        else:
            subprocess.call(["sudo", "cp", ipop_dir+"/ipop-tincan-i686",\
              ipop_dir+"/ipop-tincan"])

        # Create run.sh script file
        run = open('run.sh', 'w')
        run.write(run_script)    
        run.close()

        runcontrol = open("rc.local", 'w')
        runcontrol.write(autostart)
        runcontrol.close()

        for i in range(0, instance_count):
            path="/var/lib/lxc/ipop" + str(i) + "/rootfs/home/ubuntu/"
            config["xmpp_username"] = str(i) + "@ejabberd"
            config["xmpp_password"] = str(i)
            config["controller_logging"] = "DEBUG"
            config["tincan_logging"] = 2
 
            # Create config.json file for each isntance
            configfile = open('config.json', 'w')
            configfile.write(json.dumps(config))
            configfile.close()
            # Copies ipop-tincan, svpn_controller, config.json, run.sh files
            # to each isntance FS
            subprocess.call(["sudo", "cp", ipop_dir+"/ipop-tincan",\
              ipop_dir+"/svpn_controller.py", ipop_dir+"/ipoplib.py",\
              "config.json", "run.sh", path])

            subprocess.call(["sudo", "chown", user_group, path + \
                             "/ipop-tincan"])
            subprocess.call(["sudo", "chown", user_group, path + \
                             "/svpn_controller.py"])
            subprocess.call(["sudo", "chown", user_group, path+"/ipoplib.py"])
            subprocess.call(["sudo", "chown", user_group, path+"/config.json"])
            subprocess.call(["sudo", "chmod", "+x",\
                            path+"/svpn_controller.py"])
            subprocess.call(["sudo", "chmod", "+x",\
                            path+"/run.sh"])

            subprocess.call(["sudo", "cp", "rc.local","/var/lib/lxc/ipop" + \
                               str(i)+"/rootfs/etc/rc.local"])
           
            # Register users on XMPP server
            subprocess.call(["sudo", "ejabberdctl", "unregister", str(i),\
                             "ejabberd"])
            subprocess.call(["sudo", "ejabberdctl", "register", str(i),\
                             "ejabberd", str(i)])

        # Register friendship information to XMPP server
        for i in range(0, instance_count):
            for j in range(0, instance_count):
                subprocess.call(["sudo", "ejabberdctl", "add_rosteritem",\
                  str(i), "ejabberd", str(j), "ejabberd", str(i),"friends",\
                  "both"])
                subprocess.call(["sudo", "ejabberdctl", "add_rosteritem",\
                  str(j), "ejabberd", str(i), "ejabberd", str(j),"friends",\
                 "both"])

    def test_copy(self):
        for i in range(0, instance_count):
            path="/var/lib/lxc/ipop" + str(i) + "/rootfs/home/ubuntu/"
            ret = subprocess.call(["sudo", "ls", path+"ipop-tincan",\
                  path+"config.json", path+"/ipoplib.py",\
                  path+"svpn_controller.py", path+"run.sh"])
            self.assertTrue(ret == 0)

    def test_run(self):
        for i in range(0, instance_count):
            ret = subprocess.call(["sudo", "lxc-start", "-d", "-n",\
                                   "ipop"+str(i)])
            self.assertTrue(ret == 0)

        time.sleep(30)

        for i in range(0, instance_count):
            for j in range(1, instance_count):
                ret = subprocess.call(["sudo", "lxc-attach", "-n",\
                        "ipop"+str(i), "--", "ping", "172.31.0." + str(100+j),
                        "-c", "10"])
                self.assertTrue(ret == 0)
            



if __name__ == '__main__':
    #unittest.main()

    #suite = unittest.TestLoader().loadTestsFromTestCase(TestInstall)
    #suite = unittest.TestLoader().loadTestsFromTestCase(TestLxcCreate)
    suite = unittest.TestLoader().loadTestsFromTestCase(TestSocialVPN)

    unittest.TextTestRunner(verbosity=2).run(suite)


