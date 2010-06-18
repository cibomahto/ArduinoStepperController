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
