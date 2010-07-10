#!/usr/bin/python

# Interactive test program for the pololu stepper patch
# Can be used to generate fixed speed requests on any of the
# first three stepper motors.

from CameraController import *
from StepperAxis import *

import serial
import time
import sys

handlerXYZ = SerialHandler(port="/dev/ttyUSB1", baud=9600)
handlerA = SerialHandler(port="/dev/ttyUSB0", baud=9600)

stepperA = stepperAxis(0, handlerA)
stepperX = stepperAxis(1, handlerXYZ)
stepperY = stepperAxis(2, handlerXYZ)
stepperZ = stepperAxis(3, handlerXYZ)
camera = CameraController()

aJog = 20
xJog = 1
yJog = 1
zJog = 36

maxTime = 180

def getCommandsFromFile(filename):
    scriptfile = open(filename)

    # Read in the file, stopping if we find an error
    motionpoints = []
    linecount = 0
    for line in scriptfile:
        linecount += 1
        if line.startswith("#"):
            continue
        elif line.startswith("GO "):
            points = line.split()
            try:
                motionpoints.append(["GO", int(points[1]), int(points[2]), int(points[3]), int(points[4])])
            except:
                print "error reading", linecount, ": ", line
                exit(2)
        elif line.startswith("HOME "):
            points = line.split()
            try:
                motionpoints.append(["HOME", int(points[1])])
            except:
                print "error reading", linecount, ": ", line
                exit(1)
        elif line.startswith("SNAP "):
            points = line.split()
            try:
                motionpoints.append(["SNAP", int(points[1])])
            except:
                print "error reading", linecount, ": ", line
                exit(2)
    return motionpoints

def waitForDone():
    timeoutTime = time.time() + maxTime
    allDone = False

    # While there is still time, and we haven't received an immediate
    # response
    while ( time.time() < timeoutTime ):
        if not (stepperA.busy() or stepperX.busy() or stepperY.busy() or stepperZ.busy()):
            return

    # Timed out. TODO: throw exception
    raise NameError("timed out waiting for steppers to complete movement!")


def runCommands(points, dirname):
    pointcount = 0
    for point in points:
        print point
        if (point[0] == "GO"):
            stepperA.moveAbsolute(point[1])
            stepperX.moveAbsolute(point[2])
            stepperY.moveAbsolute(point[3])
            stepperZ.moveAbsolute(point[4])

            waitForDone()

        elif(point[0] == "HOME"):
            if (point[1] == 0):
                stepperA.home()
            elif (point[1] == 1):
                stepperX.home()
            elif (point[1] == 2):
                stepperY.home()
            elif (point[1] == 3):
                stepperZ.home()

            waitForDone()

        elif(point[0] == "SNAP"):
            if(point[1] == 0):
                camera.capture('%s/%010d.jpg' % (dirname, pointcount))

        pointcount += 1

def usage():
    print "file=?"

def main(argv):
    input = argv[0]

    print input

    points = getCommandsFromFile(input)

    dirname = input + "_pics"
    if not os.path.exists(dirname):
        os.makedirs(dirname)

    runCommands(points, dirname)

if __name__ == "__main__":
    main(sys.argv[1:])
