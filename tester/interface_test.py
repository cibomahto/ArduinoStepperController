#!/usr/bin/python

# Do some testing of the interface

import unittest
import serial
import time
import random

ser = serial.Serial('/dev/ttyUSB0', 9600, timeout = 4)

# Number of valid stepper axis we have
controllerAxisCount = 4

# Size of the controller's message buffer, in characters
controllerMessageBufferSize = 64

class controllerTest(unittest.TestCase):
    def setUp(self):
        self.flushSerial()
    
    def flushSerial(self):
        """ Bring the stepper motor controller serial interface to a known state """

        # First, write a newline to flush out anything that was in stepper's
        # receive buffer
        ser.write("\n")

        # Then, send an ALIVE message to be sure we are talking to something
        ser.write("ALIVE\n")

        # Keep reading data until we get a newline, or time out after 10 seconds
        timeoutTime = time.time() + 10
        gotAckAlive = False
        message = ""
        while ( time.time() < timeoutTime and gotAckAlive == False ):
            message += ser.read()
            if ( message.endswith("ACK ALIVE\n") ):
                gotAckAlive = True

        if ( gotAckAlive == False ):
            self.fail("timeout waiting for response from stepper")


class GETtests(controllerTest):
    """ GET parameters not currently supported """
    def testInvalidParams(self):
        ser.write("GET PIZZA\n")
        response = ser.readline()
        self.assertTrue(response.startswith("ERROR "))
    def testIncompleteParams(self):
        ser.write("GET POS\n")
        response = ser.readline()
        self.assertTrue(response.startswith("ERROR "))
    def testVersion(self):
        ser.write("GET VERSION\n");
        response = ser.readline()
        self.assertEqual(response[:16], "ACK GET VERSION ")
    def testIndex(self):
        ser.write("GET INDEX\n");
        response = ser.readline()
        self.assertEqual(response[:14], "ACK GET INDEX ")
    def testMaxVelocityFails(self):
        ser.write("GET MAX_VEL 0\n")
        response = ser.readline()
        self.assertTrue(response.startswith("ERROR "))
    def testAccelFails(self):
        ser.write("GET ACCEL 0\n")
        response = ser.readline()
        self.assertTrue(response.startswith("ERROR "))
    def testPosValid(self):
        for i in range(0, controllerAxisCount):
            ser.write("GET POS " + str(i) + "\n")
            response = ser.readline()
            self.assertEqual(response[:14], "ACK GET POS " + str(i) + " ")
    def testPosNegativeAxis(self):
        ser.write("GET POS -1\n")
        response = ser.readline()
        self.assertTrue(response.startswith("ERROR "))
    def testPosOutOfBoundsAxis(self):
        ser.write("GET POS " + str(controllerAxisCount) + "\n")
        response = ser.readline()
        self.assertTrue(response.startswith("ERROR "))



class SETtests(controllerTest):
    """ SET parameters not currently supported """
    def testInvalidParams(self):
        ser.write("SET PIZZA\n")
        response = ser.readline()
        self.assertTrue(response.startswith("ERROR "))
    def testIncompleteParams(self):
        ser.write("SET ACCEL\n")
        response = ser.readline()
        self.assertTrue(response.startswith("ERROR "))
    def testCantSetVersion(self):
        ser.write("SET VERSION 10\n")
        response = ser.readline()
        self.assertTrue(response.startswith("ERROR "))
    def testSetIndex(self):
        # Read in the existing index, overwrite it, test that worked, then
        # restore the original
        ser.write("GET INDEX\n")
        response = ser.readline()
        self.assertEqual(response[:14], "ACK GET INDEX ")
        originalIndex = long(response[14:])

        ser.write("SET INDEX " + str(originalIndex + 1) + "\n")
        response = ser.readline()
        self.assertTrue(response.startswith("ACK SET INDEX " + str(originalIndex + 1)))

        ser.write("GET INDEX\n");
        response = ser.readline()
        self.assertTrue(response.startswith("ACK GET INDEX " + str(originalIndex + 1)))

        ser.write("SET INDEX " + str(originalIndex) + "\n")
        response = ser.readline()
        self.assertTrue(response.startswith("ACK SET INDEX " + str(originalIndex)))

        ser.write("GET INDEX\n");
        response = ser.readline()
        self.assertTrue(response.startswith("ACK GET INDEX " + str(originalIndex)))
    def testMaxVelocityFails(self):
        ser.write("SET MAX_VEL 0 0\n")
        response = ser.readline()
        self.assertTrue(response.startswith("ERROR "))
    def testAccelFails(self):
        ser.write("SET ACCEL 0 0\n")
        response = ser.readline()
        self.assertTrue(response.startswith("ERROR "))

class HOMEtests(controllerTest):
    """ HOME not currently supported """
    def testNegativeAxis(self):
        ser.write("HOME -1\n")
        response = ser.readline()
        self.assertTrue(response.startswith("ERROR "))
    def testOutOfBoundsAxis(self):
        ser.write("HOME " + str(controllerAxisCount) + " 0 0\n")
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

class STATEtests(controllerTest):
    """ Test that the system responds to the STATE command. Note that we
        can't check that it will respond correctly in all cases from here.
        """
    def testIsReadyState(self):
        ser.write("STATE\n")
        response = ser.readline()
        self.assertEqual(response, "ACK STATE READY\n")


class GOtests(controllerTest):
    """ Tests that excite the stepper motors, run with caution! """
    def testNegativeAxis(self):
        ser.write("GO -1 0 0\n")
        response = ser.readline()
        self.assertTrue(response.startswith("ERROR "))
    def testOutOfBoundsAxis(self):
        ser.write("GO " + str(controllerAxisCount) + " 0 0\n")
        response = ser.readline()
        self.assertTrue(response.startswith("ERROR "))
    def testIncompleteParams(self):
        ser.write("GO 0 0\n")
        response = ser.readline()
        self.assertTrue(response.startswith("ERROR "))
    def testMoves(self):
        """ For each axis, jog it forward a bit, then backward """
        for i in range(0, controllerAxisCount):
            # Move the axis
            ser.write("GO " + str(i) + " 5000 5000\n")
            response = ser.readline()
            self.assertEqual(response, "ACK GO " + str(i) + " 5000 5000\n")
            
            # For kicks, check that the state is being reported correctly
            ser.write("STATE\n")
            response = ser.readline()
            self.assertEqual(response, "ACK STATE GOING\n")

            time.sleep(2)

            response = ser.readline()
            self.assertEqual(response, "NOTICE DONE " + str(i) + "\n")

            ser.write("STATE\n")
            response = ser.readline()
            self.assertEqual(response, "ACK STATE READY\n")

            # Check that it got there
            ser.write("GET POS " + str(i) + "\n")
            response = ser.readline()
            self.assertEqual(response, "ACK GET POS " + str(i) + " 5000\n")

            # Then move it back
            ser.write("GO " + str(i) + " 0 5000\n")
            response = ser.readline()
            self.assertEqual(response, "ACK GO " + str(i) + " 0 5000\n")

            # For kicks, check that the state is being reported correctly
            ser.write("STATE\n")
            response = ser.readline()
            self.assertEqual(response, "ACK STATE GOING\n")

            time.sleep(2)

            response = ser.readline()
            self.assertEqual(response, "NOTICE DONE " + str(i) + "\n")

            ser.write("STATE\n")
            response = ser.readline()
            self.assertEqual(response, "ACK STATE READY\n")

            # And check that it made it back
            ser.write("GET POS " + str(i) + "\n")
            response = ser.readline()
            self.assertEqual(response, "ACK GET POS " + str(i) + " 0\n")


class FUZZtests(controllerTest):
    """ Throw a bunch of random stuff at the board, then see if it still
        responds """
    def testFillBuffer(self):
        # See if we can use the entire buffer, and if there is an error if we
        # go over the length

        self.assertEqual(ser.inWaiting(), 0)

        # Pack the buffer until it is a character short of being full
        for i in range(0, controllerMessageBufferSize - 1):
            ser.write('x')
        self.assertEqual(ser.inWaiting(), 0)

        # Then fill it and look for a response
        ser.write('x')
        response = ser.readline()
        self.assertTrue(response.startswith("ERROR "))

    def testLotsOfJunk(self):
        seed = time.time()
        print "Seeding with time:", seed
        random.seed(seed)

        # Send a long string of random junk
        for i in range(0, 2000):
            ser.write(chr(random.randint(0,255)))
       
        # Wait until all data has been sent
        ser.flush()

        # Clear any received data, then see if the system is still responsive
        self.flushSerial()
        ser.write("STATE\n")
        response = ser.readline()
        self.assertEqual(response, "ACK STATE READY\n")


if __name__ == '__main__':
    suite = unittest.TestSuite()

    suite.addTest(unittest.TestLoader().loadTestsFromTestCase(GETtests))
    suite.addTest(unittest.TestLoader().loadTestsFromTestCase(SETtests))
    suite.addTest(unittest.TestLoader().loadTestsFromTestCase(HOMEtests))
    suite.addTest(unittest.TestLoader().loadTestsFromTestCase(STATEtests))
    suite.addTest(unittest.TestLoader().loadTestsFromTestCase(GOtests))
    suite.addTest(unittest.TestLoader().loadTestsFromTestCase(FUZZtests))

    unittest.TextTestRunner(verbosity=2).run(suite)

