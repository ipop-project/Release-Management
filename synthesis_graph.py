#!/usr/bin/env python

import networkx as nx
import socialModels as sm
import subprocess 
import sys

g = nx.barabasi_albert_graph(2000, 2)
#g = sm.nearestNeighbor_mod(2000, 0.1, 1)

nodes = g.number_of_nodes()
edges = g.size()
avg_cc = nx.average_clustering(g)

print >> sys.stderr, nodes, edges, avg_cc

#print g.nodes()
#print g.edges()

distance_table = {}

for i in g.nodes():
    distance_table[i] = {}
    distance_table[i][1] = []
for i, j in g.edges():
    distance_table[i][1].append(j)

def get_peers(depth):
    for i in g.nodes():
        distance_table[i][depth+1] = []
    for i in g.nodes():
        for j in distance_table[i][depth]:
            for k, l in g.edges():
                if j == k:
                    exists = False
                    for m in range(1, depth+1):
                        if l in distance_table[i][m]:
                            exists = True
                        if l in distance_table[i][depth+1]:
                            exists = True
                    if not exists:
                        distance_table[i][depth+1].append(l)
    

depth = 1
while True:
    get_peers(depth)
    brk = False
    count = 0
    for i in g.nodes():
       count += len(distance_table[i][depth])
       if count == 0:
           brk = True 
    if brk:
        break
    depth += 1
    print depth, "on going"

fo = open("distance_table", "w")
fo.write(str(distance_table))
fo.close()


for i in g.nodes():
  subprocess.call(["sudo", "ejabberdctl", "unregister", str(i), "ejabberd"])

for i in g.nodes():
  subprocess.call(["sudo", "ejabberdctl", "register", str(i), "ejabberd", str(i)])

for i in g.edges():
  subprocess.call(["sudo", "ejabberdctl", "add_rosteritem", str(i[0]), "ejabberd", str(i[1]), "ejabberd", str(i[1]), "friends", "both"])
  subprocess.call(["sudo", "ejabberdctl", "add_rosteritem", str(i[1]), "ejabberd", str(i[0]), "ejabberd", str(i[0]), "friends", "both"])
