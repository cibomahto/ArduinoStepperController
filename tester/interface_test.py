#!/usr/bin/python

# Do some testing of the interface

import unittest
import serial
import time

ser = serial.Serial('/dev/ttyUSB0', 9600, timeout = 5)

# Number of valid stepper axis we have
stepperAxisCount = 4

def flushSerial():
    ser.write("\n")
    time.sleep(.1)
    ser.flushInput()


class GETPOStests(unittest.TestCase):
    """ Tests that we get valid responses for existent and nonexistent axis.
        Note that we can't check for numerical formatting here, because we
        can't change the stepper position. """
    def setUp(self):
        flushSerial()
    def testValidRequests(self):
        for i in range(0, stepperAxisCount):
            ser.write("GETPOS " + str(i) + "\n")
            response = ser.readline()
            self.assertEqual(response[:13], "ACK GETPOS " + str(i) + " ")
    def testIncompleteParams(self):
        ser.write("GETPOS\n")
        response = ser.readline()
        self.assertTrue(response.startswith("ERROR "))
    def testNegativeAxis(self):
        ser.write("GETPOS -1\n")
        response = ser.readline()
        self.assertTrue(response.startswith("ERROR "))
    def testOutOfBoundsAxis(self):
        ser.write("GETPOS " + str(stepperAxisCount) + "\n")
        response = ser.readline()
        self.assertTrue(response.startswith("ERROR "))


class GETtests(unittest.TestCase):
    """ GET parameters not currently supported """
    def setUp(self):
        flushSerial()
    def testInvalidParams(self):
        ser.write("GET PIZZA\n")
        response = ser.readline()
        self.assertTrue(response.startswith("ERROR "))
    def testIncompleteParams(self):
        ser.write("GET POS\n")
        response = ser.readline()
        self.assertTrue(response.startswith("ERROR "))
    def testNotSupported(self):
        ser.write("GET POS 0\n")
        response = ser.readline()
        self.assertTrue(response.startswith("ERROR "))

class SETtests(unittest.TestCase):
    """ SET parameters not currently supported """
    def setUp(self):
        flushSerial()
    def testInvalidParams(self):
        ser.write("SET PIZZA\n")
        response = ser.readline()
        self.assertTrue(response.startswith("ERROR "))
    def testIncompleteParams(self):
        ser.write("SET ACCEL\n")
        response = ser.readline()
        self.assertTrue(response.startswith("ERROR "))
    def testNotSupported(self):
        ser.write("SET ACCEL 0 0\n")
        response = ser.readline()
        self.assertTrue(response.startswith("ERROR "))

class HOMEtests(unittest.TestCase):
    """ HOME not currently supported """
    def setUp(self):
        flushSerial()
    def testNegativeAxis(self):
        ser.write("HOME -1\n")
        response = ser.readline()
        self.assertTrue(response.startswith("ERROR "))
    def testOutOfBoundsAxis(self):
        ser.write("HOME " + str(stepperAxisCount) + " 0 0\n")
        response = ser.readline()
        self.assertTrue(response.startswith("ERROR "))
    def testIncompleteParams(self):
        ser.write("HOME\n")
        response = ser.readline()
        self.assertTrue(response.startswith("ERROR "))
    def testNotSupported(self):
        ser.write("HOME 0\n")
        response = ser.readline()
        self.assertTrue(response.startswith("ERROR "))

class STATEtests(unittest.TestCase):
    """ Test that the system responds to the STATE command. Note that we
        can't check that it will respond correctly in all cases from here.
        """
    def setUp(self):
        flushSerial()
    def testIsReadyState(self):
        ser.write("STATE\n")
        response = ser.readline()
        self.assertEqual(response, "ACK STATE READY\n")


class GOtests(unittest.TestCase):
    """ Tests that excite the stepper motors, run with caution! """
    def setUp(self):
        flushSerial()
    def testNegativeAxis(self):
        ser.write("GO -1 0 0\n")
        response = ser.readline()
        self.assertTrue(response.startswith("ERROR "))
    def testOutOfBoundsAxis(self):
        ser.write("GO " + str(stepperAxisCount) + " 0 0\n")
        response = ser.readline()
        self.assertTrue(response.startswith("ERROR "))
    def testIncompleteParams(self):
        ser.write("GO 0 0\n")
        response = ser.readline()
        self.assertTrue(response.startswith("ERROR "))
    def testMoves(self):
        """ For each axis, jog it forward a bit, then backward """
        for i in range(0, stepperAxisCount):
            # Move the axis
            ser.write("GO " + str(i) + " 100 5000\n")
            response = ser.readline()
            self.assertEqual(response, "ACK GO " + str(i) + " 100 5000\n")
            
            # For kicks, check that the state is being reported correctly
            ser.write("STATE\n")
            response = ser.readline()
            self.assertEqual(response, "ACK STATE GOING\n")

            time.sleep(1)

            ser.write("STATE\n")
            response = ser.readline()
            self.assertEqual(response, "ACK STATE READY\n")

            # Check that it got there
            ser.write("GETPOS " + str(i) + "\n")
            response = ser.readline()
            self.assertEqual(response, "ACK GETPOS " + str(i) + " 100\n")

            # Then move it back
            ser.write("GO " + str(i) + " 0 5000\n")
            response = ser.readline()
            self.assertEqual(response, "ACK GO " + str(i) + " 0 5000\n")

            # For kicks, check that the state is being reported correctly
            ser.write("STATE\n")
            response = ser.readline()
            self.assertEqual(response, "ACK STATE GOING\n")

            time.sleep(1)

            ser.write("STATE\n")
            response = ser.readline()
            self.assertEqual(response, "ACK STATE READY\n")

            # And check that it made it back
            ser.write("GETPOS " + str(i) + "\n")
            response = ser.readline()
            self.assertEqual(response, "ACK GETPOS " + str(i) + " 0\n")


if __name__ == '__main__':
#    unittest.TextTestRunner(verbosity=2).run()
    unittest.main()
