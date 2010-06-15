#!/usr/bin/python

# Interactive test program for the pololu stepper patch
# Can be used to generate fixed speed requests on any of the
# first three stepper motors.
#
# Really rough
# Requires python, pygame (for arrow key input)

import sys, pygame
from pygame.locals import *

pygame.init()


import serial

size = width, height = 800, 600
screen = pygame.display.set_mode(size, DOUBLEBUF)
pygame.display.set_caption('Stepper Man!')


ser = serial.Serial('/dev/ttyUSB0', 9600)

countR = 0
stepSize = 6400
speed = 6
stepper = 0

while 1:
    for event in pygame.event.get():
        if event.type == pygame.QUIT:
            sys.exit()

        keystate = pygame.key.get_pressed()

        if (keystate[K_LEFT]):
            countR -= stepSize
            time = speed * stepSize
            ser.write("GO " + str(stepper) + " " + str(countR) + " " + str(time) + "\n")
            print "Speed=", speed, ", position=", countR, ", time=", time

        elif (keystate[K_RIGHT]):
            countR += stepSize
            time = speed * stepSize
            ser.write("GO " + str(stepper) + " " + str(countR) + " " + str(time) + "\n")
            print "Speed=", speed, ", position=", countR, ", time=", time
            
        if (keystate[K_UP]):
            stepper = (stepper + 1) % 3
            print "Speed=", speed, ", position=", countR

        elif (keystate[K_DOWN]):
            stepper = (stepper + 2) % 3
            print "Speed=", speed, ", position=", countR


ser.close()
