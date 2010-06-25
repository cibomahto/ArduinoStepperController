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

moveSize = 100

class StepperTest(wx.App):
    def OnInit(self):
        self.res = xrc.XmlResource("test_gui.xrc")
        self.frame = self.res.LoadFrame(None, "TestInterface")
        EVT_BUTTON(self, XRCID("ID_CONNECT"), self.OnConnect)
        EVT_BUTTON(self, XRCID("ID_DISCONNECT"), self.OnDisconnect)
        EVT_BUTTON(self, XRCID("ID_SEND"), self.OnSend)
        self.sendText = xrc.XRCCTRL(self.frame, "ID_SEND_TEXT")

        EVT_BUTTON(self, XRCID("ID_AXIS_0_PLUS"), self.OnAxis0Plus)
        EVT_BUTTON(self, XRCID("ID_AXIS_0_MINUS"), self.OnAxis0Minus)
        EVT_BUTTON(self, XRCID("ID_AXIS_0_UPDATE"), self.OnAxis0Update)
        self.axis0Location = xrc.XRCCTRL(self.frame, "ID_AXIS_0_LOCATION")

        EVT_BUTTON(self, XRCID("ID_AXIS_1_PLUS"), self.OnAxis1Plus)
        EVT_BUTTON(self, XRCID("ID_AXIS_1_MINUS"), self.OnAxis1Minus)
        EVT_BUTTON(self, XRCID("ID_AXIS_1_UPDATE"), self.OnAxis1Update)
        self.axis1Location = xrc.XRCCTRL(self.frame, "ID_AXIS_1_LOCATION")

        EVT_BUTTON(self, XRCID("ID_AXIS_2_PLUS"), self.OnAxis2Plus)
        EVT_BUTTON(self, XRCID("ID_AXIS_2_MINUS"), self.OnAxis2Minus)
        EVT_BUTTON(self, XRCID("ID_AXIS_2_UPDATE"), self.OnAxis2Update)
        self.axis2Location = xrc.XRCCTRL(self.frame, "ID_AXIS_2_LOCATION")

        self.frame.Show()

        self.ser = serial.Serial()

        self.stepperX = stepperAxis(1)
        self.stepperY = stepperAxis(2)
        self.stepperR = stepperAxis(3)

        return True

    def OnConnect(self, event):
        self.ser = serial.Serial('/dev/ttyUSB0', 9600)
        print "Connected!"
#        self.stepperX.readPosition(self.ser)
#        self.axis1Location.SetValue(str(self.stepperX.getPosition()))

    def OnDisconnect(self, event):
        self.ser.close()
        print "Disconnected!"

    def OnSend(self, event):
        self.ser.write(str(self.sendText.GetValue()) + '\n')

    def OnAxis0Plus(self, event):
        self.stepperX.moveRelative(moveSize)
        self.stepperX.update(self.ser)
        self.axis0Location.SetValue(str(self.stepperX.getPosition()))

    def OnAxis0Minus(self, event):
        self.stepperX.moveRelative(-moveSize)
        self.stepperX.update(self.ser)
        self.axis0Location.SetValue(str(self.stepperX.getPosition()))

    def OnAxis0Update(self, event):
        self.stepperX.moveAbsolute(int(self.axis0Location.GetValue()))
        self.stepperX.update(self.ser)

    def OnAxis1Plus(self, event):
        self.stepperY.moveRelative(moveSize)
        self.stepperY.update(self.ser)
        self.axis1Location.SetValue(str(self.stepperY.getPosition()))

    def OnAxis1Minus(self, event):
        self.stepperY.moveRelative(-moveSize)
        self.stepperY.update(self.ser)
        self.axis1Location.SetValue(str(self.stepperY.getPosition()))

    def OnAxis1Update(self, event):
        self.stepperY.moveAbsolute(int(self.axis1Location.GetValue()))
        self.stepperY.update(self.ser)

    def OnAxis2Plus(self, event):
        self.stepperR.moveRelative(moveSize)
        self.stepperR.update(self.ser)
        self.axis2Location.SetValue(str(self.stepperR.getPosition()))

    def OnAxis2Minus(self, event):
        self.stepperR.moveRelative(-moveSize)
        self.stepperR.update(self.ser)
        self.axis2Location.SetValue(str(self.stepperR.getPosition()))

    def OnAxis2Update(self, event):
        self.stepperR.moveAbsolute(int(self.axis2Location.GetValue()))
        self.stepperR.update(self.ser)


def main():
    app = StepperTest(0)
    app.MainLoop()

if __name__ == '__main__':
    main()

