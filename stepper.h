#ifndef _STEPPER_H
#define _STEPPER_H

#include "WProgram.h"

#define MAX_STEPPERS 4

enum STOP_MODES {
  S_KEEP_ENABLED,
  S_DISABLE,
};

enum HOME_DIRECTION {
  H_FORWARD,
  H_BACKWARD,
};

enum STEPPER_STATE {
  S_READY,
  S_MOVING,
  S_FINISHED_MOVING,
  S_HOMING_A,
  S_HOMING_B,
  S_FINISHED_HOMING,
  S_ERROR,
};

class Stepper {
// Global stepper stuff
 public:  
  static void doStepperInterrupts();
  
  static uint8_t count();
  
  // Returns true if the specified stepper index is in bounds
  static boolean indexValid(const int index);
  
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
  // TODO: Implement this
  Stepper(uint8_t enablePin_, uint8_t stepPin_, uint8_t directionPin_);
  Stepper(uint8_t enablePin_, uint8_t stepPin_, uint8_t directionPin_, uint8_t limitPin_);
  void doReset();
  
  // newPosition Position to move to, in stepper counts
  // ticks       Time it should take to get there, in milliseconds
  boolean moveAbsolute(long newPosition, long& time);
  // steps       Steps to take, in stepper counts
  // ticks       Time it should take to move, in milliseconds
  boolean moveRelative(long steps, long& time);
  
  // Find the limit switch, and set it to the 0 position
  boolean home();
  
  // Get the position
  long getPosition();

  long getMaxVelocity();
  boolean setMaxVelocity(long velocity_);

  long getAcceleration();
  boolean setAcceleration(long acceleration_);
  
  STOP_MODES getStopMode();
  boolean setStopMode(STOP_MODES stopMode_);
  
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
    STOP_MODES stopMode;           // Determines if the motors should be disabled when not moving
    HOME_DIRECTION homeDirection;  // Determines which direction the axis should search for home in
    boolean canHome;               // True if the axis supports homing

    stepperSettings(long maxVelocity_, long acceleration_, STOP_MODES stopMode_, HOME_DIRECTION homeDirection_, boolean canHome_) {
      maxVelocity = maxVelocity_;
      acceleration = acceleration_;
      stopMode = stopMode_;
      homeDirection = homeDirection_;
      canHome = canHome_;
    }
  };
  
  stepperSettings settings;
 
  uint8_t enablePin;
  uint8_t stepPin;
  uint8_t directionPin;
  uint8_t limitPin;

  STEPPER_STATE state;
  
  long position;      //< Current position
  long stepsLeft;     //< Number of counts until final position is reached
  int8_t direction;   //< Direction we are heading 1=pos, -1=neg
  
  long deltax;
  long deltay;
  long error;
  
  void doInterrupt();
};

#endif
