#!/usr/bin/python
import math;
outfile = open("x_jog_test","w");

for a in range (0, 4):
    outfile.write("GO 0 400 0 0\n")
    outfile.write("GO 0 0 0 0\n")
