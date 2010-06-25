#!/usr/bin/python

# Interactive test program for the pololu stepper patch
# Can be used to generate fixed speed requests on any of the
# first three stepper motors.

from CameraController import *
from StepperAxis import *

import serial
import time


ser = serial.Serial("/dev/ttyUSB0", 9600)

stepper = stepperAxis(0)
camera = CameraController()


camera.capture('%010d.jpg' % stepper.getPosition())
for i in range(0,32):
    stepper.moveRelative(4000)
    stepper.update(ser)
    time.sleep(25)
    stepper.moveRelative(-4000)
    stepper.update(ser)
    time.sleep(25)
#    camera.capture('%010d.jpg' % stepper.getPosition())
    camera.capture('%010d.jpg' % i)


