#!/usr/bin/python

# Interactive test program for the pololu stepper patch
# Can be used to generate fixed speed requests on any of the
# first three stepper motors.
#
# Really rough

import wx
from wx import xrc
from wx import *
from wx.xrc import *

import serial
from StepperAxis import *

class StepperTest(wx.App):
    def OnInit(self):
        self.res = xrc.XmlResource("test_gui.xrc")
        self.frame = self.res.LoadFrame(None, "TestInterface")
        EVT_BUTTON(self, XRCID("ID_CONNECT"), self.OnConnect)
        EVT_BUTTON(self, XRCID("ID_DISCONNECT"), self.OnDisconnect)
        EVT_BUTTON(self, XRCID("ID_SEND"), self.OnSend)
        self.sendText = xrc.XRCCTRL(self.frame, "ID_SEND_TEXT")

        EVT_BUTTON(self, XRCID("ID_AXIS_1_PLUS"), self.OnAxis1Plus)
        EVT_BUTTON(self, XRCID("ID_AXIS_1_MINUS"), self.OnAxis1Minus)
        EVT_BUTTON(self, XRCID("ID_AXIS_1_UPDATE"), self.OnAxis1Update)
        self.axis1Location = xrc.XRCCTRL(self.frame, "ID_AXIS_1_LOCATION")

        self.frame.Show()

        self.ser = serial.Serial()

        self.stepperX = stepperAxis(0)
        self.stepperY = stepperAxis(1)
        self.stepperR = stepperAxis(2)

        return True

    def OnConnect(self, event):
        self.ser = serial.Serial('/dev/ttyUSB0', 9600)
        print "Connected!"
        self.stepperX.readPosition(self.ser)
        self.axis1Location.SetValue(str(self.stepperX.getPosition()))

    def OnDisconnect(self, event):
        self.ser.close()
        print "Disconnected!"

    def OnSend(self, event):
        self.ser.write(str(self.sendText.GetValue()) + '\n')

    def OnAxis1Plus(self, event):
        self.stepperX.moveRelative(100)
        self.stepperX.update(self.ser)
        self.axis1Location.SetValue(str(self.stepperX.getPosition()))

    def OnAxis1Minus(self, event):
        self.stepperX.moveRelative(-100)
        self.stepperX.update(self.ser)
        self.axis1Location.SetValue(str(self.stepperX.getPosition()))

    def OnAxis1Update(self, event):
        self.stepperX.moveAbsolute(int(self.axis1Location.GetValue()))
        self.stepperX.update(self.ser)


def main():
    app = StepperTest(0)
    app.MainLoop()

if __name__ == '__main__':
    main()

