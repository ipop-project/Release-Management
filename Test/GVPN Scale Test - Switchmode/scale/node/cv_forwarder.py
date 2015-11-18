#!/usr/bin/env python

import time     # interval timer
import sys      # arguments
import socket   # listener
import select   # check for packets
import json     # decoding packets

def main():

    try:
        ipv4      = str(sys.argv[1])
        recv_port = int(sys.argv[2])
        send_port = int(sys.argv[3])
    except:
        print('usage: ' + sys.argv[0] + ' <ipv4> <recv_port> <send_port>')
        sys.exit()

    # initialize receiver socket
    recv_sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    recv_sock.bind((ipv4, recv_port))

    # initialize sender socket
    send_sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    send_sock.bind((ipv4, send_port))
    send_sock.listen(1)
    connection, addr = send_sock.accept()
    print("connected to " + str(addr))

    # main loop
    while True:

        try:
            data = recv_sock.recv(8192)

            head = json.dumps("{:04}".format(len(data))).encode("utf8")

            connection.send(head + data)

        except socket.error:
            connection, addr = send_sock.accept()
            print("connected to " + str(addr))

if __name__ == "__main__":
    main()

