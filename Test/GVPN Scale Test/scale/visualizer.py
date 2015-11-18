#!/usr/bin/env python

# pacman -S tk

from threading import Thread # listener thread
from math import sin,cos,pi  # gui positioning
import hashlib               # calculating uid
import time                  # ttl and refresh
import tkinter               # gui library
import sys                   # arguments and exit
import socket                # listener
import json                  # decoding packets

# canvas object - graphical user interface tool
class Canvas(object):
    # initialize canvas
    def __init__(self, width, height, margin, title):
        # canvas constants

        self.WIDTH  = width
        self.HEIGHT = height
        self.MARGIN = margin
        self.MID_X  = self.WIDTH / 2
        self.MID_Y  = self.HEIGHT / 2
        self.RADIUS = min(self.MID_X, self.MID_Y) - self.MARGIN

        # create canvas
        self.tk = tkinter.Tk()
        self.tk.title(title)
        self.tk.configure(background='black')
        self.tk.resizable(0,0)
        self.canvas = tkinter.Canvas(self.tk, width=self.WIDTH, height=self.HEIGHT, bg='black')
        self.canvas.pack()

    # canvas operators
    def draw_circle(self, x, y, r, f=None):
        self.canvas.create_oval(x-r,y-r,x+r,y+r, outline='black', width=1, fill=f)
    def draw_line(self, x_i, y_i, x_j, y_j, f=None):
        self.canvas.create_line(x_i, y_i, x_j, y_j, fill=f, width=1)
    def draw_text(self, x, y, t):
        self.canvas.create_text(x, y, text=t, fill='white', justify=tkinter.CENTER)
    def update(self):
        self.tk.update()
    def clear(self):
        self.canvas.delete('all')

# network object - state of the network
class Network(object):
    class Node(object):
        def __init__(self, x, y, n_x, n_y, ip4):
            self.name       = ip4.split('.')[3]
            self.ip4        = ip4
            self.x          = x
            self.y          = y
            self.n_x        = n_x
            self.n_y        = n_y
            self.state      = 0
            self.links      = {
                "successor": [],
                "chord": [],
                "on_demand": [],
                "inbound": []
            }

    def __init__(self, nr_nodes, ip4_mask_addr):
        self.uid_nid_table = {} # uid to node index mapping
        self.uid_ip4_table = {} # uid to ipv4 mapping
        self.nodes = []         # list of nodes indexed by node index

        # create nodes (sorted by uid)
        for i in range(nr_nodes):
            ip4 = ip4_mask_addr + str(i // 256) + "." + str(i % 256)
            uid = hashlib.sha1(bytes(ip4,'utf-8')).hexdigest()[:40]
            self.uid_ip4_table[uid] = ip4

        sorted_uid = sorted(self.uid_ip4_table.keys())
        for i in range(nr_nodes):
            uid = sorted_uid[i]
            ip4 = self.uid_ip4_table[uid]
            self.uid_nid_table[uid] = i

            x   = canvas.RADIUS * cos(i*2*pi/nr_nodes) + canvas.MID_X
            y   = canvas.RADIUS * sin(i*2*pi/nr_nodes) + canvas.MID_Y
            n_x = (20 + canvas.RADIUS) * cos(i*2*pi/nr_nodes) + canvas.MID_X
            n_y = (20 + canvas.RADIUS) * sin(i*2*pi/nr_nodes) + canvas.MID_Y

            self.nodes.append(Network.Node(x, y, n_x, n_y, ip4))

# listener thread - listens for network state and updates the data accordingly
def listener(protocol, recv_ipv4, recv_port):

    # initialize listener socket
    if protocol == "tcp":
        recv_sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        recv_sock.connect((recv_ipv4, recv_port))
    else:
        recv_sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        recv_sock.bind((recv_ipv4, recv_port))

    while runnable:

        msg = {}
        if protocol == "tcp":

            # stream head
            stream = recv_sock.recv(6)
            while len(stream) < 6:
                stream += recv_sock.recv(6 - len(stream))
            head = int(stream.decode("utf8")[1:5])

            # stream data
            data = ""
            while head != 0:
                stream = recv_sock.recv(head)
                data += stream.decode("utf8")
                head -= len(stream)

        else:
            gram = recv_sock.recv(8192)
            data = gram.decode("utf8")

        msg = json.loads(data)

        print(network.uid_ip4_table[msg["uid"]])
        node_index = network.uid_nid_table[msg["uid"]]

        network.nodes[node_index].state      = int(time.time())

        for con_type in ["successor", "chord", "on_demand", "inbound"]:
            network.nodes[node_index].links[con_type] = [network.uid_nid_table[x] for x in msg[con_type]]

def main():
    global runnable
    global canvas
    global network

    # parse arguments
    try:
        protocol  = str(sys.argv[1])
        recv_ipv4 = str(sys.argv[2])
        recv_port = int(sys.argv[3])
        nr_nodes  = int(sys.argv[4])
        canvas_sz = int(sys.argv[5])
    except:
        print('usage: ' + sys.argv[0] + ' <protocol> <recv_ipv4> <recv_port> <nr_nodes> <canvas_sz>')
        sys.exit()

    # hard-coded arguments
    ip4_addr = "172.31.0.0"
    ip4_mask = 16
    ip4_mask_addr = "172.31."

    # set runnable state; create canvas and graph objects
    runnable = True
    canvas = Canvas(canvas_sz, canvas_sz, 50, 'IPOP Network Visualizer')
    network = Network(nr_nodes, ip4_mask_addr)

    # launch listener
    thread_listener = Thread(target=listener, args=(protocol, recv_ipv4, recv_port,))
    thread_listener.start()

    # main loop
    while True:
        nr_online_nodes = 0
        nr_successor_links = 0
        nr_chord_links = 0
        nr_on_demand_links = 0

        # draw links
        for node in network.nodes:
            if int(time.time()) < node.state + 10: # assumed online

                for peer in node.links["on_demand"]:
                    canvas.draw_line(node.x, node.y, network.nodes[peer].x, network.nodes[peer].y, 'orange')
                    nr_on_demand_links += 1
                for peer in node.links["chord"]:
                    canvas.draw_line(node.x, node.y, network.nodes[peer].x, network.nodes[peer].y, 'white')
                    nr_chord_links += 1
                for peer in node.links["successor"]:
                    canvas.draw_line(node.x, node.y, network.nodes[peer].x, network.nodes[peer].y, 'yellow')
                    nr_successor_links += 1

        # draw nodes
        for node in network.nodes:
            if int(time.time()) < node.state + 10: # assumed online
                canvas.draw_circle(node.x, node.y, 5, 'green')
                nr_online_nodes += 1
            else:
                canvas.draw_circle(node.x, node.y, 5, 'red')
            canvas.draw_text(node.n_x, node.n_y, node.name)

        canvas.draw_text(16, 10, "ipv4")
        canvas.draw_text(20, 25, "nodes")
        canvas.draw_text(34, 40, "successors")
        canvas.draw_text(22, 55, "chords")
        canvas.draw_text(34, 70, "on-demand")

        canvas.draw_text(120, 10, ip4_addr + "/" + str(ip4_mask))
        canvas.draw_text(120, 25, nr_online_nodes)
        canvas.draw_text(120, 40, nr_successor_links)
        canvas.draw_text(120, 55, nr_chord_links)
        canvas.draw_text(120, 70, nr_on_demand_links // 2)

        canvas.update()
        canvas.clear()

        time.sleep(0.1)

if __name__ == "__main__":
    main()
