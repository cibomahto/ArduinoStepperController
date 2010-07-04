#!/usr/bin/python

outfile = open("x_jog_test","w");

outfile.write("-50 0 0 0 0\n")
outfile.write("0 0 0 0 0\n")

for a in range (0, 50):
    outfile.write("2000 0 0 0 1\n")
    outfile.write("0 0 0 0 0\n")
