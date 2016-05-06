#!/usr/bin/env python3

# pacman -S tk
import tkinter                      # gui library
from math import sin,cos,pi         # math for positioning
import time                         # ttl and refresh
from threading import Thread, Lock  # listener thread and sync
import sys                          # arguments and exit
import socket                       # listener
import json                         # decoding packets
import os                           # full process exit
import traceback                    # informative traceback

class Canvas(object):
    def __init__(self):
        # canvas constants
        self.header     = 75
        self.margin     = 50
        self.height     = 350
        self.width      = 350
        self.center_y   = self.height // 2 + self.header
        self.center_x   = self.width // 2
        self.radius     = min(self.height // 2, self.width // 2) - self.margin
        self.real_height= self.height + self.header

        # create canvas
        self.tk = tkinter.Tk()
        self.tk.title('IPOP Network Visualizer')
        self.tk.configure(background='black')
        self.tk.resizable(0,0)
        self.canvas = tkinter.Canvas(self.tk, width=self.width, height=self.real_height, bg='black')
        self.canvas.pack(fill=tkinter.BOTH, expand=tkinter.YES)

    # canvas operators
    def draw_circle(self, x, y, r, f=None):
        self.canvas.create_oval(x-r,y-r,x+r,y+r, outline='black', width=1, fill=f)
    def draw_line(self, x_i, y_i, x_j, y_j, f=None):
        self.canvas.create_line(x_i, y_i, x_j, y_j, fill=f, width=1)
    def draw_text(self, x, y, t, a='left'):
        if a == 'left': anchor = tkinter.W
        else: anchor = tkinter.CENTER
        self.canvas.create_text(x, y, text=t, fill='white', anchor=anchor)
    def update(self):
        self.tk.update()
    def clear(self):
        self.canvas.delete('all')

### listener thread
def listener(protocol, recv_ipv4, recv_port):

    try:
        # initialize listener socket
        if protocol == "tcp":
            recv_sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            recv_sock.connect((recv_ipv4, recv_port))
        else:
            recv_sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
            recv_sock.bind((recv_ipv4, recv_port))

        while True:

            ### listen for messages
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

            print(msg["name"], msg["uid"], msg["ip4"])

            ### update node state
            _lock.acquire()

            # update attributes
            _nodes[msg["uid"]] = {}
            _nodes[msg["uid"]]["name"]      = msg["name"]
            _nodes[msg["uid"]]["state"]     = msg["state"]
            _nodes[msg["uid"]]["uid"]       = msg["uid"]
            _nodes[msg["uid"]]["ip4"]       = msg["ip4"]
            _nodes[msg["uid"]]["links"]     = msg["links"]
            _nodes[msg["uid"]]["vis_time"]  = int(time.time())

            # update node positions if new node
            if "vis_x" not in _nodes[msg["uid"]]:
                for i, uid in enumerate(sorted(_nodes.keys())):
                    _nodes[uid]["vis_x"]      = _canvas.radius*cos(i*2*pi/len(_nodes)-pi/2)+_canvas.center_x
                    _nodes[uid]["vis_y"]      = _canvas.radius*sin(i*2*pi/len(_nodes)-pi/2)+_canvas.center_y
                    _nodes[uid]["vis_name_x"] = (20+_canvas.radius)*cos(i*2*pi/len(_nodes)-pi/2)+_canvas.center_x
                    _nodes[uid]["vis_name_y"] = (20+_canvas.radius)*sin(i*2*pi/len(_nodes)-pi/2)+_canvas.center_y

            _lock.release()

    except:
        print(traceback.format_exc())
        os._exit(1)

### main / drawer thread
def main():

    ### init
    global _nodes
    global _lock
    global _canvas
    global _vpn_type

    _nodes = {}
    _lock = Lock()
    _canvas = Canvas()

    LIVE_TIME = 10 # time (in seconds) since a node last updated (assumed alive)

    # parse arguments
    try:
        protocol  = str(sys.argv[1])
        recv_ipv4 = str(sys.argv[2])
        recv_port = int(sys.argv[3])
        _vpn_type = str(sys.argv[4])

        if _vpn_type != "svpn" and _vpn_type != "gvpn":
            raise ValueError
    except:
        print('usage: ' + sys.argv[0] + ' <protocol> <recv_ipv4> <recv_port> <gvpn | svpn>')
        sys.exit()

    # launch listener thread
    thread_listener = Thread(target=listener, args=(protocol, recv_ipv4, recv_port,))
    thread_listener.start()

    ### visualizer drawer
    try:
        while True:
            _lock.acquire()
            uids = list(_nodes.keys())[:]
            _lock.release()

            nr_online_nodes     = 0
            nr_successor_links  = 0
            nr_chord_links      = 0
            nr_on_demand_links  = 0
            nr_links            = 0

            # draw links
            for uid in uids:
                node = _nodes[uid]

                if int(time.time()) < node["vis_time"] + LIVE_TIME:

                    if _vpn_type == 'gvpn':
                        for peer in list(set(node["links"]["successor"] + node["links"]["chord"] + node["links"]["on_demand"])):
                            if peer in _nodes:
                                color = 'red'
                                if peer in node["links"]["successor"]:
                                    color = 'yellow'
                                    nr_successor_links = nr_successor_links + 1
                                elif peer in node["links"]["chord"]:
                                    color = 'white'
                                    nr_chord_links = nr_chord_links + 1
                                elif peer in node["links"]["on_demand"]:
                                    color = 'orange'
                                    nr_on_demand_links = nr_on_demand_links + 1
                                _canvas.draw_line(node["vis_x"], node["vis_y"], _nodes[peer]["vis_x"], _nodes[peer]["vis_y"], color)
                                nr_links = nr_links + 1
                    elif _vpn_type == 'svpn':
                        for peer in node["links"]:
                            if peer in _nodes:
                                _canvas.draw_line(node["vis_x"], node["vis_y"], _nodes[peer]["vis_x"], _nodes[peer]["vis_y"], 'white')
                                nr_links = nr_links + 1

            # draw node state
            for uid in uids:
                node = _nodes[uid]

                if int(time.time()) < node["vis_time"] + LIVE_TIME:
                    if _vpn_type == 'gvpn': 
                        color = 'red'
                        if node["state"] == "started":      color = 'blue'
                        elif node["state"] == "searching":  color = 'yellow'
                        elif node["state"] == "connecting": color = 'orange'
                        elif node["state"] == "connected":  color = 'green'
                        _canvas.draw_circle(node["vis_x"], node["vis_y"], 5, color)
                    else: #svpn
                        _canvas.draw_circle(node["vis_x"], node["vis_y"], 5, 'green')

                    nr_online_nodes = nr_online_nodes + 1
                else:
                    _canvas.draw_circle(node["vis_x"], node["vis_y"], 5, 'red')
                _canvas.draw_text(node["vis_name_x"], node["vis_name_y"], node["name"], 'center')

            # draw header details
            _canvas.draw_text(5, 10, "vpn type")
            _canvas.draw_text(5, 25, "nodes")
            _canvas.draw_text(5, 40, "links")

            if _vpn_type == 'gvpn':
                _canvas.draw_text(5, 55, "- successors")
                _canvas.draw_text(5, 70, "- chords")
                _canvas.draw_text(5, 85, "- on-demand")

            _canvas.draw_text(100, 10, _vpn_type)
            _canvas.draw_text(100, 25, str(nr_online_nodes) + "/" + str(len(uids)))
            _canvas.draw_text(100, 40, nr_links)

            if _vpn_type == 'gvpn':
                _canvas.draw_text(100, 55, nr_successor_links)
                _canvas.draw_text(100, 70, nr_chord_links)
                _canvas.draw_text(100, 85, nr_on_demand_links)

            _canvas.update()
            time.sleep(0.2)
            _canvas.clear()

    except tkinter.TclError: # exception on closed window
        os._exit(1)
    except:
        print(traceback.format_exc())
        os._exit(1)

if __name__ == "__main__":
    main()
