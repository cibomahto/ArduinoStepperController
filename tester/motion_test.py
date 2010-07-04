#!/usr/bin/python

# Interactive test program for the pololu stepper patch
# Can be used to generate fixed speed requests on any of the
# first three stepper motors.

from CameraController import *
from StepperAxis import *

import serial
import time
import sys

serXYZ = serial.Serial("/dev/ttyUSB0", 9600)
serA = serial.Serial("/dev/ttyUSB1", 9600)

stepperA = stepperAxis(0)
stepperX = stepperAxis(1)
stepperY = stepperAxis(2)
stepperZ = stepperAxis(3)
camera = CameraController()

aJog = 20
xJog = 1
yJog = 1
zJog = 36

delay = 11


def getPointsFromFile(filename):
    scriptfile = open(filename)

    # Read in the file, stopping if we find an error
    motionpoints = []
    linecount = 0
    for line in scriptfile:
        linecount += 1
        if line.startswith("#"):
            continue

        points = line.split()

        try:
            motionpoints.append([int(points[0]), int(points[1]), int(points[2]), int(points[3]), int(points[4])])
        except:
            print "error reading", linecount, ": ", line
            exit(2)

    return motionpoints

def runPoints(points, dirname):
    pointcount = 0
    for point in points:
        print point
        stepperX.moveAbsolute(point[0])
        stepperY.moveAbsolute(point[1])
        stepperZ.moveAbsolute(point[2])
#        stepperA.moveAbsolute(point[3])

        stepperX.update(serXYZ)
        stepperY.update(serXYZ)
        stepperZ.update(serXYZ)
#        stepperA.update(serA)

        time.sleep(delay)
        if( point[4] == 1 ):
          camera.capture('%s/%010d.jpg' % (dirname, pointcount))

        pointcount += 1

def usage():
    print "file=?"

def main(argv):
    input = argv[0]

    print input

    points = getPointsFromFile(input)

    dirname = input + "_pics"
    if not os.path.exists(dirname):
        os.makedirs(dirname)

    runPoints(points, dirname)

if __name__ == "__main__":
    main(sys.argv[1:])
