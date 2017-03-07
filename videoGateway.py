#!/usr/bin/env python
from select import select
import threading
import socket
import base64
import json
import time
import datetime

#UDP_BIND_REMOTE_IP = "95.31.31.166"
UDP_BIND_REMOTE_IP = "192.168.1.15"

UDP_BIND_IP = "192.168.1.15"
UDP_BIND_PORT = 6889
DATAGRAM_SIZE = 16384

class DistributionPool(threading.Thread):
        def __init__(self):
                super(DistributionPool, self).__init__()
		print "Starting distribution pool: " + str(datetime.datetime.now())
                self.socket = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
                self.socket.bind((UDP_BIND_IP, 0))
                self.incoming_port = self.socket.getsockname()[1]
                self.addresses = []


        def run(self):
                while True:
                        data, addr = self.socket.recvfrom(DATAGRAM_SIZE)
                        if not (addr in self.addresses):
                                self.addresses.append(addr)

                        for a in self.addresses:
                                if a == addr:
                                        continue
                                self.socket.sendto(data, a)


forwarded_connections = []
sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
sock.bind((UDP_BIND_IP, UDP_BIND_PORT))

while True:
        data, addr = sock.recvfrom(DATAGRAM_SIZE)
        dp = DistributionPool()
        gatewayInfo = {
                "PublicIP": UDP_BIND_REMOTE_IP,
                "PublicPort": "%d" % dp.incoming_port,
        }
        print gatewayInfo
        sock.sendto(base64.b64encode(json.dumps(gatewayInfo)), addr)

        dp.start()