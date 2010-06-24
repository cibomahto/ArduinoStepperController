#ifndef _STEPPER_H
#define _STEPPER_H

#include "WProgram.h"

#define MAX_STEPPERS 4

class Stepper {
// Global stepper stuff
 public:  
  static void doStepperInterrupts();
  
  static uint8_t count();
  
  static Stepper& getStepper(const int index);
  
  static void setup(unsigned int frequency_);
  
  static int saveSettings(int offset);
  static int restoreSettings(int offset);
  
 private:
//  static Stepper* registeredSteppers[MAX_STEPPERS];
  static uint8_t stepperCount;
  
  static unsigned int frequency;

  static boolean registerStepper(Stepper* stepper_);
  
// Instance-specific stepper stuff
 public:
  Stepper(uint8_t resetPin_, uint8_t stepPin_, uint8_t directionPin_);
  void doReset();
  
  // newPosition Position to move to, in stepper counts
  // ticks       Time it should take to get there, in milliseconds
  boolean moveAbsolute(long newPosition, long& time);
  // steps       Steps to take, in stepper counts
  // ticks       Time it should take to move, in milliseconds
  boolean moveRelative(long steps, long& time);
  
  // Get the position
  long getPosition();

  long getMaxVelocity();
  boolean setMaxVelocity(long velocity_);

  long getAcceleration();
  boolean setAcceleration(long acceleration_);
  
  // Reset the position, only works if the stepper is not in motion
  boolean setPosition(long position_);
  
  boolean busy();    //< TRUE if stepper is moving
  
  boolean checkFinished();  //< TRUE if the device just finished moving. Clears the
                            //< finished bit if set.

 private:
  // Parameters in this class are persistant across reset
  struct stepperSettings {
    long maxVelocity;
    long acceleration;
  };
  
  stepperSettings settings;
 
  uint8_t resetPin;
  uint8_t stepPin;
  uint8_t directionPin;

  boolean moving;    //< Whether we are running or not
  boolean finished;  //< True if we just finished running
  
  long position;      //< Current position
  long stepsLeft;     //< Number of counts until final position is reached
  int8_t direction;   //< Direction we are heading 1=pos, -1=neg
  
  long deltax;
  long deltay;
  long error;
  
  void doInterrupt();
};

#endif
