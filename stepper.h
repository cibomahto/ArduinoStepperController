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
  
 private:
//  static Stepper* registeredSteppers[MAX_STEPPERS];
  static uint8_t stepperCount;
  
  static unsigned int frequency;

  static boolean registerStepper(Stepper* stepper_);
  
// Instance-specific stepper stuff
 private:
  uint8_t resetPin;
  uint8_t stepPin;
  uint8_t directionPin;

  boolean moving;    //< Whether we are running or not
  
  long position;      //< Current position
  long countsLeft;    //< Number of counts until final position is reached
  int8_t direction;   //< Direction we are heading 1=pos, -1=neg
  
  long deltax;
  long deltay;
  long error;
  
  void doInterrupt();
  
 public:
  Stepper(uint8_t resetPin_, uint8_t stepPin_, uint8_t directionPin_);
  void doReset();
  
  // newPosition Position to move to, in stepper counts
  // ticks       Time it should take to get there, in terms of interrupt calls
  boolean moveAbsolute(long newPosition, long ticks);
  // newPosition Steps to take, in stepper counts
  // ticks       Time it should take to move, in terms of interrupt calls
  boolean moveRelative(long counts, long ticks);
  
  // Get the position
  long getPosition();
  
  // Reset the position, only works if the stepper is not in motion
  boolean setPosition(long position_);
  
  boolean isMoving();    //< TRUE if stepper is moving
};

#endif
