# pylint: disable=missing-docstring
try:
    import simplejson as json
except ImportError:
    import json
import os
import subprocess
import random
from distutils import spawn
import pickle
import argparse
import shutil
import time
from abc import ABCMeta, abstractmethod
import ipaddress

class Experiment():
    __metaclass__ = ABCMeta

    LAUNCH_WAIT = 6
    BATCH_SZ = 10
    VIRT = NotImplemented
    APT = spawn.find_executable("apt-get")
    CONTAINER = NotImplemented
    VIRT_IMG = NotImplemented

    def __init__(self, exp_dir=None):
        parser = argparse.ArgumentParser(description="Configures and start IPOP Docker testbed")
        parser.add_argument("--clean", action="store_true", default=False, dest="clean",
                            help="Removes all generated files and directories")
        parser.add_argument("--configure", action="store_true", default=False, dest="configure",
                            help="Generates the config files and directories")
        parser.add_argument("-v", action="store_true", default=False, dest="verbose",
                            help="Verbose output")
        parser.add_argument("--range", action="store", dest="range",
                            help="Specifies the experiment start and end range in (] interval."
                            "Ex. for 10 instances --range=1,11")
        parser.add_argument("--run", action="store_true", default=False, dest="run",
                            help="Runs the currently configured experiment")
        parser.add_argument("--end", action="store_true", default=False, dest="end",
                            help="End the currently running experiment")
        parser.add_argument("--info", action="store_true", default=False, dest="info",
                            help="Displays the current experiment configuration")
        parser.add_argument("--setup", action="store_true", default=False, dest="setup",
                            help="Updates system-wide limits by modifying \"/etc/sysctl.conf\" "
                            "and \"/etc/security/limits.conf\". This is only necessary to run "
                            "a large number of containers and requires run as root.")
        parser.add_argument("--pull", action="store_true", default=False, dest="pull",
                            help="Pulls the continer image")
        parser.add_argument("--ping", action="store", dest="ping",
                            help="Ping the specified address from each container")
        parser.add_argument("--arp", action="store", dest="arp",
                            help="arPing the specified address from each container")
        parser.add_argument("--ipop", action="store", dest="ipop",
                            help="Perform the specified service action: stop/start/restart")
        parser.add_argument("--churn", action="store", dest="churn",
                            help="Restarts the specified amount of nodes in the overlay,"
                            "one every interval. Ex --churn=num_iters,interval")

        self.args = parser.parse_args()
        self.exp_dir = exp_dir
        if not self.exp_dir:
            self.exp_dir = os.path.abspath(".")
        self.template_file = "{0}/template-config.json".format(self.exp_dir)
        self.template_bf_file = "{0}/template-bf-config.json".format(self.exp_dir)
        self.config_dir = "{0}/config".format(self.exp_dir)
        self.cores_dir = "{0}/cores".format(self.exp_dir)
        self.logs_dir = "{0}/log".format(self.exp_dir)
        self.data_dir = "{0}/test-link-utilization".format(self.exp_dir)
        self.config_file_base = "{0}/config-".format(self.config_dir)
        self.seq_file = "{0}/startup.list".format(self.exp_dir)
        self.range_file = "{0}/range_file".format(self.exp_dir)

        if self.args.range:
            rng = self.args.range.rsplit(",", 2)
            self.range_end = int(rng[1])
            self.range_start = int(rng[0])
        elif not self.args.range and os.path.isfile(self.range_file):
            with open(self.range_file) as rng_fle:
                rng = rng_fle.read().strip().rsplit(",", 2)
                self.range_end = int(rng[1])
                self.range_start = int(rng[0])
        else:
            self.range_end = self.range_start = 0
        self.total_inst = self.range_end - self.range_start
        self.seq_list = None #[range(self.range_end, self.range_start)]
        self.load_seq_list()

    @classmethod
    def runshell(cls, cmd):
        """ Run a shell command. if fails, raise an exception. """
        if cmd[0] is None:
            raise ValueError("No executable specified to run")
        resp = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        return resp

    @property
    @abstractmethod
    def gen_config(self, range_start, range_end):
        pass

    @property
    @abstractmethod
    def start_instance(self, instance):
        pass

    @property
    @abstractmethod
    def end(self):
        pass

    def clean_config(self):
        if os.path.isdir(self.config_dir):
            shutil.rmtree(self.config_dir)
            if self.args.verbose:
                print("Removed dir {}".format(self.config_dir))
        if os.path.isfile(self.seq_file):
            os.remove(self.seq_file)
            if self.args.verbose:
                print("Removed file {}".format(self.seq_file))
        if os.path.isfile(self.range_file):
            os.remove(self.range_file)
            if self.args.verbose:
                print("Removed file {}".format(self.range_file))

    def make_clean(self):
        self.clean_config()
        if os.path.isdir(self.logs_dir):
            shutil.rmtree(self.logs_dir)
            if self.args.verbose:
                print("Removed dir {}".format(self.logs_dir))
        if os.path.isdir(self.cores_dir):
            shutil.rmtree(self.cores_dir)
            if self.args.verbose:
                print("Removed dir {}".format(self.cores_dir))

    def configure(self):
        with open(self.range_file, "w") as rng_fle:
            rng_fle.write(self.args.range)
        self.gen_config(self.range_start, self.range_end)
        self.save_seq_list()

    def save_seq_list(self):
        if not self.seq_list:
            self.seq_list = list(range(self.range_start, self.range_end))
            random.shuffle(self.seq_list)
        with open(self.seq_file, "wb") as seq_fle:
            pickle.dump(self.seq_list, seq_fle)
            seq_fle.flush()
        if self.args.verbose:
            print("Container launch sequence saved with {0} entries\n{1}"
                  .format(self.total_inst, self.seq_list))

    def load_seq_list(self):
        if os.path.isfile(self.seq_file):
            with open(self.seq_file, "rb") as seq_fle:
                self.seq_list = pickle.load(seq_fle)
            if self.args.verbose:
                print("Sequence list loaded from existing file -  {0} entries\n{1}".
                      format(len(self.seq_list), self.seq_list))
                print("Using range {0}-{1}".format(self.range_start, self.range_end))

    def start_range(self, num, wait):
        cnt = 0
        sequence = self.seq_list[self.range_start-1:self.range_end-1]
        for inst in sequence:
            self.start_instance(inst)
            cnt += 1
            if cnt % num == 0 and cnt < len(sequence):
                time.sleep(wait)
        print("{0} container(s) instantiated".format(cnt))

    def run(self):
        self.start_range(Experiment.BATCH_SZ, Experiment.LAUNCH_WAIT)

    @abstractmethod
    def display_current_config(self):
        pass

    def setup_system(self):
        setup_cmds = [["./update-limits.sh"]]
        for cmd_list in setup_cmds:
            if self.args.verbose:
                print(cmd_list)
            resp = Experiment.runshell(cmd_list)
            print(resp.stdout.decode("utf-8") if resp.returncode == 0 else
                  resp.stderr.decode("utf-8"))

    @abstractmethod
    def run_container_cmd(self, cmd_line, instance_num):
        pass

    def churn(self, param):
        params = param.rsplit(",", 2)
        iters = int(params[0])
        inval = int(params[1])
        self._churn(iters, inval)

    def _churn(self, churn_count=0, interval=30):
        if churn_count == 0:
            churn_count = self.total_inst
        cnt = 0
        while cnt < churn_count:
            inst = random.choice(range(self.range_start, self.range_end))
            if self.args.verbose:
                print("Stopping node", inst)
            self.run_container_cmd(["systemctl", "stop", "ipop"], inst)
            if self.args.verbose:
                print("Waiting", interval, "seconds")
            time.sleep(interval)
            if self.args.verbose:
                print("Resuming node", inst)
            self.run_container_cmd(["systemctl", "start", "ipop"], inst)
            cnt += 1


class DockerExperiment(Experiment):
    VIRT = spawn.find_executable("docker")
    VIRT_IMG = "ipopproject/ipop-vpn:1.0"
    CONTAINER = "ipop-dkr{0}"
    NETWORK_NAMESPACE = "dkrnet"

    def __init__(self, exp_dir=None):
        super().__init__(exp_dir=exp_dir)
 
    def display_current_config(self):
        print("----Experiment Configuration----")
        print("{0} instances in range {1}-{2}".format(self.total_inst, self.range_start,
                                                      self.range_end))
        print("Config dir: {0}".format(self.config_dir))
        print("Config base filename: {0}".format(self.config_file_base))
        print("Log dir: {0}".format(self.logs_dir))
        print("Docker image name: {0}".format(DockerExperiment.VIRT_IMG))
        print("Docker container base name: {0}".format(DockerExperiment.CONTAINER[:-3]))
        print("Docker network name: {0}".format(DockerExperiment.NETWORK_NAMESPACE))
        print("".format())

    def configure(self):
       super().configure()
       self.create_network()
       self.pull_image()

    def create_network(self):
        cmd_list = [DockerExperiment.VIRT, "network", "ls", "-fname={}"
                    .format(DockerExperiment.NETWORK_NAMESPACE), "-q"]
        if self.args.verbose:
            print(cmd_list)
        resp = Experiment.runshell(cmd_list)
        if resp.returncode == 0 and not resp.stdout: #network was not previously created
            cmd_list = [DockerExperiment.VIRT, "network", "create", DockerExperiment.NETWORK_NAMESPACE]
            resp = Experiment.runshell(cmd_list)
            if self.args.verbose:
                print(cmd_list)
                print("Created Docker network namespace {}".format(resp.stdout.decode("utf-8"))
                      if resp.returncode == 0 else resp.stderr.decode("utf-8"))
        elif self.args.verbose and resp.returncode == 0 and resp.stdout:
            print("Using existing Docker network namespace {}".format(DockerExperiment.NETWORK_NAMESPACE))

    def gen_config(self, range_start, range_end):
        with open(self.template_file) as cfg_tmpl:
            template = json.load(cfg_tmpl)
        olid = template["CFx"].get("Overlays", None)
        olid = olid[0]
        node_id = template["CFx"].get("NodeId", "a000###feb6040628e5fb7e70b04f###")
        node_name = template["OverlayVisualizer"].get("NodeName", "dkr###")
        netwk = template["BridgeController"]["Overlays"][olid].get("IP4", "10.10.1.0/24")
        netwk = ipaddress.IPv4Network(netwk)
        for val in range(range_start, range_end):
            rng_str = "{0:03}".format(val)
            cfg_file = "{0}{1}.json".format(self.config_file_base, rng_str)
            node_id = "{0}{1}{2}{1}{3}".format(node_id[:4], rng_str, node_id[7:29], node_id[32:])
            node_name = "{0}{1}".format(node_name[:3], rng_str)
            node_ip = str(netwk[val])

            template["CFx"]["NodeId"] = node_id
            template["OverlayVisualizer"]["NodeName"] = node_name
            template["BridgeController"]["Overlays"][olid]["IP4"] = node_ip
            os.makedirs(self.config_dir, exist_ok=True)
            with open(cfg_file, "w") as cfg_fle:
                json.dump(template, cfg_fle, indent=2)
                cfg_fle.flush()
        if self.args.verbose:
            print("{0} config file(s) generated".format(range_end-range_start))
        self.gen_bf_config()

    def gen_bf_config(self):
        with open(self.template_bf_file) as cfg_tmpl:
            template = json.load(cfg_tmpl)
            cfg_file = "{0}{1}.json".format(self.config_file_base, "bf-cfg")
            with open(cfg_file, "w") as cfg_fle:
                json.dump(template, cfg_fle, indent=2)
                cfg_fle.flush()

        if self.args.verbose:
            print("IPOP config file(s) generated")

    def start_instance(self, instance):
        instance = "{0:03}".format(instance)
        container = DockerExperiment.CONTAINER.format(instance)
        log_dir = "{0}/dkr{1}".format(self.logs_dir, instance)
        os.makedirs(log_dir, exist_ok=True)

        cfg_file = "{0}{1}.json".format(self.config_file_base, instance)
        if not os.path.isfile(cfg_file):
            self.gen_config(instance, instance+1)

        mount_cfg = "{0}:/etc/opt/ipop-vpn/config.json".format(cfg_file)
        mount_log = "{0}/:/var/log/ipop-vpn/".format(log_dir)
        mount_data = "{0}/:/var/ipop-vpn/".format(self.data_dir)
        args = ["--rm", "--privileged"]
        opts = "-d"
        img = DockerExperiment.VIRT_IMG
        cmd = "/sbin/init"
        bf_cfg_file = "{0}{1}.json".format(self.config_file_base, "bf-cfg")
        mount_bf_cfg = "{0}:/etc/opt/ipop-vpn/bf-cfg.json".format(bf_cfg_file)
        cmd_list = [DockerExperiment.VIRT, "run", opts, "-v", mount_cfg, "-v", mount_log, "-v",
                    mount_bf_cfg, "-v", mount_data, args[0], args[1], "--name", container,
                    "--network", DockerExperiment.NETWORK_NAMESPACE, img, cmd]
        if self.args.verbose:
            print(cmd_list)
        resp = Experiment.runshell(cmd_list)
        print(resp.stdout.decode("utf-8") if resp.returncode == 0 else resp.stderr.decode("utf-8"))

    def run_container_cmd(self, cmd_line, instance_num):
        cmd_list = [DockerExperiment.VIRT, "exec", "-it"]
        inst = "{0:03}".format(instance_num)
        container = DockerExperiment.CONTAINER.format(inst)
        cmd_list.append(container)
        cmd_list += cmd_line
        resp = Experiment.runshell(cmd_list)
        if self.args.verbose:
            print(cmd_list)
            print(resp.stdout.decode("utf-8"))

    def run_cmd_on_range(self, cmd_line):
        report = dict(fail_count=0, fail_node=[])
        for inst in self.seq_list[self.range_start-1:self.range_end-1]:
            cmd_list = [DockerExperiment.VIRT, "exec", "-it"]
            inst = "{0:03}".format(inst)
            container = DockerExperiment.CONTAINER.format(inst)
            cmd_list.append(container)
            cmd_list += cmd_line
            resp = Experiment.runshell(cmd_list)
            if self.args.verbose:
                print(cmd_list)
                print(resp.stdout.decode("utf-8"))
            if resp.returncode != 0:
                report["fail_count"] += 1
                report["fail_node"].append("node-{0}".format(inst))
        rpt_msg = "{0}: {1}/{2} failed\n{3}".format(cmd_line, report["fail_count"],
                                                    self.range_end - self.range_start,
                                                    report["fail_node"])
        print(rpt_msg)


    def pull_image(self):
        cmd_list = [DockerExperiment.VIRT, "images", DockerExperiment.VIRT_IMG, "-q"]
        resp = Experiment.runshell(cmd_list)
        if resp.returncode == 0 and not resp.stdout: #image not dl
            cmd_list = [DockerExperiment.VIRT, "pull", DockerExperiment.VIRT_IMG]
            resp = Experiment.runshell(cmd_list)
            if self.args.verbose:
                print(cmd_list)
                print(resp.stdout.decode("utf-8") if resp.returncode == 0 else resp.stderr.decode("utf-8"))

    def stop_range(self):
        cnt = 0
        cmd_list = [DockerExperiment.VIRT, "kill"]
        sequence = self.seq_list[self.range_start-1:self.range_end-1]
        for inst in sequence:
            cnt += 1
            inst = "{0:03}".format(inst)
            container = DockerExperiment.CONTAINER.format(inst)
            cmd_list.append(container)
        if self.args.verbose:
            print(cmd_list)
        resp = Experiment.runshell(cmd_list)
        print(resp.stdout.decode("utf-8") if resp.returncode == 0 else
              resp.stderr.decode("utf-8"))
        print("{0} Docker container(s) terminated".format(cnt))

    def end(self):
        self.run_cmd_on_range(["systemctl", "stop", "ipop"])
        self.stop_range()

    def run_ping(self, target_address):
        report = dict(fail_count=0, fail_node=[])
        for inst in range(self.range_start, self.range_end):
            cmd_list = [DockerExperiment.VIRT, "exec", "-it"]
            inst = "{0:03}".format(inst)
            container = DockerExperiment.CONTAINER.format(inst)
            cmd_list.append(container)
            cmd_list += ["ping", "-c1"]
            cmd_list.append(target_address)
            resp = Experiment.runshell(cmd_list)
            if self.args.verbose:
                print(cmd_list)
                print("ping ", target_address, "\n", resp.stdout.decode("utf-8"))
            if resp.returncode != 0:
                report["fail_count"] += 1
                report["fail_node"].append("node-{0}".format(inst))
        rpt_msg = "ping {0}: {1}/{2} failed\n{3}".format(target_address, report["fail_count"],
                                                         self.range_end - self.range_start,
                                                         report["fail_node"])
        print(rpt_msg)

    def run_arp(self, target_address):
        for inst in range(self.range_start, self.range_end):
            cmd_list = [DockerExperiment.VIRT, "exec", "-it"]
            inst = "{0:03}".format(inst)
            container = DockerExperiment.CONTAINER.format(inst)
            cmd_list.append(container)
            cmd_list += ["arping", "-C1"]
            cmd_list.append(target_address)
            if self.args.verbose:
                print(cmd_list)
            resp = Experiment.runshell(cmd_list)
            print(resp.stdout.decode("utf-8") if resp.returncode == 0 else
                  resp.stderr.decode("utf-8"))

    def run_svc_ctl(self, svc_ctl):
        if svc_ctl == "stop":
            self.run_cmd_on_range(["systemctl", "stop", "ipop"])
        elif svc_ctl == "start":
            self.run_cmd_on_range(["systemctl", "start", "ipop"])
        elif svc_ctl == "restart":
            self.run_cmd_on_range(["systemctl", "restart", "ipop"])
        else:
            print("Invalid service control specified, only accepts start/stop/restart")

def main(): # pylint: disable=too-many-return-statements
    exp = DockerExperiment()

    if exp.args.run and exp.args.end:
        print("Error! Both run and end were specified.")
        return

    if exp.args.info:
        exp.display_current_config()
        return

    if exp.args.setup:
        exp.setup_system()
        return

    if exp.args.pull:
        exp.pull_image()
        return

    if exp.args.clean:
        exp.make_clean()
        return

    if exp.range_end - exp.range_start <= 0:
        print("Invalid range, please fix RANGE_START={0} RANGE_END={1}".
              format(exp.range_start, exp.range_end))
        return

    if exp.args.configure:
        exp.configure()

    if exp.args.run:
        exp.run()
        return

    if exp.args.end:
        exp.end()
        return

    if exp.args.ping:
        exp.run_ping(exp.args.ping)
        return

    if exp.args.arp:
        exp.run_arp(exp.args.arp)
        return

    if exp.args.ipop:
        exp.run_svc_ctl(exp.args.ipop)
        return

    if exp.args.churn:
        exp.churn(exp.args.churn)
        return

if __name__ == "__main__":
    main()
