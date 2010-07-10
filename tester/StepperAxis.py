
import time
import serial
import Queue

class SerialHandler:
    def __init__(self, port = "", baud = "", timeout = 10):
        self.clientMap = {}
        # mapping from clients to axis
        # Queue of return messages (DONE, etc) to send to clients
        if (port <> ""):
            self.connect(port, baud)

        self.timeout = 15
        self.messageBuffer = ""
        self.messages = []

    def connect(self, port, baud=9600):
        self.ser = serial.Serial(port, baud)
    def disconnect(self):
        self.ser.close()
    def sendCommand(self, command):
        self.ser.write(command)
        print(command)
        
        message = self.getImmediateResponse()
        return message

    def getImmediateResponse(self):
        """ Wait for an immediate response (ACK, ERROR) from the serial port.
            If we find a delayed response along the way (NOTICE), save it for
            later. """
        
        # Calculate when we should time out
        timeoutTime = time.time() + self.timeout
        gotImmediate = False

        # While there is still time, and we haven't received an immediate
        # response
        while ( time.time() < timeoutTime ):
            message = self.checkForResponse()
            if (message != ""):
                return message
                        
        # Timed out. TODO: throw exception
        raise NameError("timed out waiting for response from Arduino!")

    def checkForResponse(self):
        # Read new characters in one at a time, and if we get an \n,
        # check if we understand the message
        message = ""

        while (self.ser.inWaiting() > 0):
            self.messageBuffer += self.ser.read(1)

            if (self.messageBuffer.endswith("\n")):
                message = self.messageBuffer.split('\n',1)[0]
                self.messageBuffer = ""

                print "Got: >>", message, "<<"

                if (message.startswith("ACK ") or message.startswith("ERROR ")):
                    print "Got immediate response, returning."
                    return message
                elif (message.startswith("NOTICE ")):
                    print "Binning message."
                    self.messages.append(message)
                    print self.messages
                else:
                    print "TODO: Message not understood, error?"

        return ""

    def pollSerial(self):
        message = self.checkForResponse()
        if (message <> ""):
            raise NameError("Got immediate message when it wasn't expected: ", message)
   
    def getDelayedResponse(self, axis):
        """ Get any messages that are waiting for this axis """
        self.pollSerial()

        for i in range(len(self.messages)):
            if (int(self.messages[i].split()[2]) == axis):
                message = self.messages[i]
                print "Found message: ", message
                self.messages.pop(i)
                return message

        # TODO: Throw?
        return ""



    def flushSerial(self):
        """ Bring the stepper motor controller serial interface to a known state """

        # First, write a newline to flush out anything that was in stepper's
        # receive buffer
        self.ser.write("\n")

        # Then, send an ALIVE message to be sure we are talking to something
        self.ser.write("ALIVE\n")

        # Keep reading data until we get a newline, or time out after 10 seconds
        timeoutTime = time.time() + 10
        gotAckAlive = False
        message = ""
        while ( time.time() < timeoutTime and gotAckAlive == False ):
            message += self.ser.read()
            if ( message.endswith("ACK ALIVE\n") ):
                gotAckAlive = True

                if ( gotAckAlive == False ):
                    return "ERROR timeout waiting for response from stepper"


class stepperAxis:
    def __init__(self, axis, handler):
        self.axis = axis
        self.handler = handler

        self.lastPosition = 0
        self.requestedPosition = 0

        self.isBusy = False


    def update(self):
        # TODO: Drop this function???
        if (self.busy()):
            raise NameError("Stepper busy!")

        self.isBusy = True

#        if ( self.lastPosition != self.currentPosition ):
        command = "GO " + str(self.axis) + " " + str(self.requestedPosition) + " 0\n"
        # TODO: handle failures here
        self.handler.sendCommand(command)
        self.lastPosition = self.requestedPosition

    def moveRelative(self, counts):
        if (self.busy()):
            raise NameError("Stepper busy!")

        self.requestedPosition += counts
        self.update()

    def moveAbsolute(self, position):
        if (self.busy()):
            raise NameError("Stepper busy!")

        self.requestedPosition = position
        self.update()

    def getPosition(self):
        return self.currentPosition

    def home(self):
        if (self.busy()):
            raise NameError("Stepper busy!")

        command = "HOME " + str(self.axis) + "\n"
        message = self.handler.sendCommand(command)
        # TODO check return values

    def readPosition(self):
        command = "GET POS " + str(self.axis) + "\n"
        message = self.handler.sendCommand(command)

        if ( message[:12] == "ACK GET POS " + str(self.axis) ):
            self.currentPosition = int(message[13:])

    def busy(self):
        if (not self.isBusy):
            return False
        
        # Check if we finished and just don't know
        message = self.handler.getDelayedResponse(self.axis)
        
        if (message == ""):
            return True

        # TODO: Actually check the message
        self.isBusy = False
        return False

