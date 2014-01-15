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

for i in g.nodes():
  subprocess.call(["sudo", "ejabberdctl", "unregister", str(i), "ejabberd"])

for i in g.nodes():
  subprocess.call(["sudo", "ejabberdctl", "register", str(i), "ejabberd", str(i)])

for i in g.edges():
  subprocess.call(["sudo", "ejabberdctl", "add_roisteritem", str(i[0]), "ejabberd", str(i[1]), "ejabberd", str(i[1]), "friends", both])

