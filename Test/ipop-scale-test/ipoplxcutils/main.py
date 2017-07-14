#!/usr/bin/env python

import os
import subprocess
import cmd
import tempfile
import lxc
import json
from datetime import datetime
from pymongo import MongoClient

class ScaleTestCL(cmd.Cmd):
    """ Scale test cmd module shell built to interface with
        lxc containers and mongodb
    """

    def __init__(self, testing_db):
        cmd.Cmd.__init__(self)
        self.prompt = "(scale-test) "
        self.ipopdb = testing_db

    def do_ping(self, arg):
        """Ping test: e.g. ping node1 node2 5
           format: cmd (node to send ping) (node to receive ping) (packet count)
        """
        nodes = arg.split()
        if len(nodes) == 3:
            ping_output = {}
            try:
                ping_output = ping_test(nodes[0], nodes[1], int(nodes[2]))
            except ValueError as err:
                print(err)
                return
            print(ping_output)
            parsed_ping = parse_ping(ping_output)
            document = format_ping(parsed_ping, nodes[0], nodes[1])
            self.ipopdb["ping"].insert_one(document)
        else:
            print("Invalid arguments. See `help ping`.")

    def do_pingall(self, arg):
        """Test ping between all active nodes
            e.g. pingall 5
            format: cmd (packet count)
        """
        default_packet_count = 2
        args = arg.split()
        if len(args) == 0:
            print("Staring pingall with default packet count of 2.")
            results = pingall_test(default_packet_count)
            self.ipopdb['ping'].insert_many(results)
        elif len(args) > 1:
            print("Expecting only one optional argument. Type help pingall for more info.")
        elif not str.isdigit(arg):
            print("Packet count argument must be integer.")
        else:
            packet_count = int(arg)
            results = pingall_test(packet_count)
            self.ipopdb['ping'].insert_many(results)

    def do_iperf(self, arg):
        """ Iperf test:
            e.g. iperf node1 node2
            format: cmd (client node) (server node)
        """
        nodes = arg.split()
        if len(nodes) == 2:
            iperf_output = {}
            try:
                iperf_output = iperf_test(nodes[0], nodes[1])
            except ValueError as err:
                print(err)
                return
            print(iperf_output)
            document = format_iperf(iperf_output, nodes[0], nodes[1], "unicast")
            self.ipopdb["iperf"].insert_one(document)
        else:
            print("Invalid arguments. See `help iperf`.")

    def do_status(self, arg):
        """List defined containers with associated ip addreses"""
        container_status_check()

    def do_exportdata(self, arg):
        """Pulls current data from ping and iperf collections
        and dumps then into files in data directory
        """
        data_directory_path = "./data"
        if not os.path.exists(data_directory_path):
            os.makedirs(data_directory_path)
        subprocess.call(["mongoexport", "-d", "ipopdb", "-c", "ping",
                         "--jsonArray", "--out", "./data/ping.json"])
        pretty_json_file("./data/ping.json")
        subprocess.call(["mongoexport", "--db", "ipopdb", "--collection", "iperf",
                         "--out", "./data/iperf.json"])
        pretty_json_file("./data/iperf.json")
        print("files saved in {}".format(data_directory_path))


    def do_exit(self, arg):
        """Exit command-line scale testing interface"""
        return True

def pretty_json_file(filepath):
    with open(filepath, "r+") as f:
        data = {}
        try:
            data = json.load(f)
        except ValueError:
            print("No data in {}".format(f.name))
        f.seek(0)
        json.dump(data, f, sort_keys=True, indent=4, separators=(',', ': '))
        f.truncate()


def get_ipop_ip(container):
    ips = container.get_ips()
    if len(ips) != 2:
        raise ValueError("IPOP Virtual Network Interface is not running on " +\
                          "receiver {0}".format(container.name))
    return ips[1]

def run(node, command):
    with tempfile.NamedTemporaryFile() as out_file:
        node.attach_wait(lxc.attach_run_command, command, stdout=out_file.file)
        out_file.seek(0)
        output = out_file.read()
        return output

def ping_test(sender_name, receiver_name, packet_count):
    sender = lxc.Container(sender_name)
    receiver = lxc.Container(receiver_name)

    r_ipop_ip = get_ipop_ip(receiver)

    ping_command = ["ping", "-c", str(packet_count), r_ipop_ip]
    ping_output = run(sender, ping_command)
    return ping_output

def iperf_test(client_name, server_name):
    client = lxc.Container(client_name)
    server = lxc.Container(server_name)

    server_ip = get_ipop_ip(server)

    iperf_client_command = ["iperf3", "-J", "-t", "5", "-c", server_ip]
    iperf_server_command = ["iperf3", "-s", "-1", "-B", server_ip, "-D"]
    run(server, iperf_server_command)
    iperf_output = run(client, iperf_client_command)
    return iperf_output

# def multicast_iperf_test(client_name):
    # client = lxc.Container(client_name)

    # # iperf_client_command = ["iperf", "-u", "-c", server_ip]
    # # iperf_server_command = ["iperf3", "-s", "-1", "-B", server_ip, "-D"]

    # list = lxc.list_containers(as_object=True)
    # for node in list:
        # if node.name not in ["default", client_name]:
            # print(node.name)

def pingall_test(packet_count):
    test_results = []
    containers = lxc.list_containers(as_object=True)
    for current_container in containers:
        name = current_container.name
        if name not in ["default"]:
            for other_container in containers:
                other_name = other_container.name
                if other_name not in ["default", name]:
                    test_results.append(ping_and_parse(current_container,
                                                       name, other_name,
                                                       packet_count))
    return test_results

def ping_and_parse(sender, sender_name, receiver_name, packet_count):
    ping_output = {}
    try:
        get_ipop_ip(sender)

    except ValueError as err:
        ping_output = {"error": str(err)}
        print("{0} (ipop down) -X {1}" \
                .format(sender_name, receiver_name))
        return format_ping(ping_output, sender_name, receiver_name)

    try:
        ping_output = parse_ping(ping_test(sender_name, receiver_name,
                                           packet_count))
        print("{0} -> {1} with packet loss {2}%" \
          .format(sender_name, receiver_name, ping_output["packet_loss"]))

    except ValueError as err:
        ping_output = {"error": str(err)}
        print("{0} -X {1} (ipop down)" \
                .format(sender_name, receiver_name))
    return format_ping(ping_output, sender_name, receiver_name)

def parse_ping(ping_lines):
    ping_lines = ping_lines.split('\n')
    stats = ping_lines[-3:]
    xsi = [i for i, line in enumerate(stats) if "packet loss" in line]
    xmit_stats = stats[xsi[0]].split(",")
    pli = [x for x, data in enumerate(xmit_stats) if "packet loss" in data]
    packet_loss = float(xmit_stats[pli[0]].split("%")[0])
    packet_count = float(xmit_stats[0].split("packets")[0])
    if packet_loss > 50:
        return {"packet_loss": packet_loss, "packet_count": packet_count}
    timing_stats = stats[1].split("=")[1].split("/")
    ping_min = float(timing_stats[0])
    ping_avg = float(timing_stats[1])
    ping_max = float(timing_stats[2])
    return {"packet_loss": packet_loss,
            "packet_count": packet_count,
            "ping_min": ping_min,
            "ping_avg": ping_avg,
            "ping_max": ping_max
           }

def format_ping(parsed_ping, sender, receiver):
    return {"sender": sender,
            "receiver": receiver,
            "results": parsed_ping,
            "timestamp": datetime.now()
           }

def format_iperf(iperf_output, sender, receiver, mode):
    return {"sender": sender,
            "receiver": receiver,
            "results": json.loads(iperf_output),
            "mode": mode,
            "timestamp": datetime.now()
           }

def container_status_check():
    containers = lxc.list_containers(as_object=True)
    for container in containers:
        if container.name != "default":
            status = "running" if container.running else "not running"
            print("Container: {0} is {1} | ip addresses: {2}" \
                  .format(container.name, status, container.get_ips()))

def main():
    """Peform various testing operations on scale test environment
    """
    client = MongoClient()
    ipopdb = client['ipopdb']
    ScaleTestCL(ipopdb).cmdloop()


if __name__ == "__main__":
    main()
