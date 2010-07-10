#!/usr/bin/python
import math;
outfile = open("soa_beetle","w");


rangeX = 7500.0/2
rangeY = 8000.0/2
rangeZ = 7200.0/6
rangeA = 1800.0
MAX = 600

for a in range (0, MAX+1):
    outfile.write("GO " + str((int)(a*rangeA/MAX)-100) + " " + str(int((math.sin(a*2*math.pi*3/MAX)+1)*rangeX)) + " " + str(int((math.cos(a*2*math.pi*3/MAX)+1)*rangeY)) + " " + str(int(a*rangeZ/MAX)) + "\n" )
    outfile.write("SNAP 0\n")
