#!/usr/bin/env python

import argparse
import socket
import time

def serve(port):
    while True:
        sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        sock.bind(("", port))
        data, addr = sock.recvfrom(2048)
        print addr
        print data

def send_ping(transport):
    i = 0
    while True:
        sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        dest = (transport.split(":")[0], int(transport.split(":")[1]))
        sock.sendto(str(i), dest)
        i += 1
        time.sleep(1)

if __name__=='__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument("-s", help="Run UDP server for ping",
                        dest="port", type=int, action='store')
    parser.add_argument("-c", help="Repeately send udp message (ADDR:PORT)",
                        dest="transport", type=str, action='store')
    args = parser.parse_args()
    if args.port == None:
        send_ping(args.transport)
    else:
        serve(args.port)
