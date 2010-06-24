
import time


def getMessage(ser):
    timeoutTime = time.time() + 10
    gotAckAlive = False
    message = ""
    while ( time.time() < timeoutTime and gotAckAlive == False ):
        message += ser.read()
        if ( message.endswith("\n") ):
            gotAckAlive = True

    if ( gotAckAlive == False ):
        return "Error"

    return message
    
def flushSerial(ser):
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


class stepperAxis:
    def __init__(self, axis):
        self.axis = axis
        self.lastPosition = 0
        self.currentPosition = 0


    def update(self, ser):
        if ( self.lastPosition != self.currentPosition ):
            ser.write("GO " + str(self.axis) + " " + str(self.currentPosition) + " " + str(abs(self.currentPosition-self.lastPosition)) + "\n")
            self.lastPosition = self.currentPosition

    def moveRelative(self, counts):
        self.currentPosition += counts

    def moveAbsolute(self, position):
        self.currentPosition = position

    def getPosition(self):
        return self.currentPosition

    def readPosition(self, ser):
        flushSerial(ser)
        ser.write("GET POS " + str(self.axis) + "\n");

        message = getMessage(ser)

        if ( message[:12] == "ACK GET POS " + str(self.axis) ):
            self.currentPosition = int(message[13:])

