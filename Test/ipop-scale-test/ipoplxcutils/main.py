#!/usr/bin/env python

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
            ping_output = ping_test(nodes[0], nodes[1], int(nodes[2]))
            print(ping_output)
            parsed_ping = parse_ping(ping_output)
            document = format_ping(parsed_ping, nodes[0], nodes[1])
            self.ipopdb["ping"].insert_one(document)
        else:
            print("Invalid arguments")

    def do_pingall(self, arg):
        """Test ping between all active nodes
            e.g. pingall 5
            format: cmd (packet count)
        """
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
            iperf_output = iperf_test(nodes[0], nodes[1])
            print(iperf_output)
            document = format_iperf(iperf_output, nodes[0], nodes[1], "unicast")
            self.ipopdb["iperf"].insert_one(document)
        else:
            print("Invalid arguments")

    def do_status(self, arg):
        """List defined containers with associated ip addreses"""
        container_status_check()

    def do_exit(self, arg):
        """Exit command-line scale testing interface"""
        return True

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
                    ping_output = ping_test(name, other_name, packet_count)
                    parsed_ping = parse_ping(ping_output)
                    test_results.append(format_ping(parsed_ping, name, other_name))
                    print("{0} -> {1} with packet loss {2}%" \
                          .format(name, other_name,parsed_ping["packet_loss"]))
    return test_results

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
