/*
 * DragonStopMotion library for Arduino v2.1
 *
 * Changelog:
 *
 * Version 2.1
 *   Added DRAGON_CC_MSG to represent "Capture Complete" message from Dragon Stop Motion.
 *   Added commandStereoPosition to represent the stereo index for the exposure.
 *
 * Version 2.0
 *   Initial version 
 */

#ifndef DragonStopMotion_h
#define DragonStopMotion_h

#include <inttypes.h>
#include <HardwareSerial.h>

#define DSM_PIN_COUNT 16

#define DRAGON_SHOOT_CMD  1
#define DRAGON_DELETE_CMD 2
#define DRAGON_PLAY_CMD   3
#define DRAGON_LIVE_CMD   4

#define DRAGON_SHOOT_MSG    1
#define DRAGON_DELETE_MSG   2
#define DRAGON_POSITION_MSG 3
#define DRAGON_CC_MSG 4

#define DRAGON_EXP_NAME_LENGTH  16

class DragonStopMotion
{

public:
  DragonStopMotion(HardwareSerial& port);
  void activatePin(int pin, int activeValue, int command);
  void activatePin(int pin, int activeValue, int command, int arg);
  void deactivatePin(int pin);

  void processPins();
  
  int processSerial();
  
  void shootFrame(int frames);
  
  void deleteFrame();

  void togglePlay();

  void goToLive();
  
  int commandFrame;
  int commandExposure;
  char commandExposureName[DRAGON_EXP_NAME_LENGTH + 1];
  int commandStereoPosition;
  
private:
  HardwareSerial& port;

  int command[DSM_PIN_COUNT];
  int logicActive[DSM_PIN_COUNT];
  int arg[DSM_PIN_COUNT];
  int value[DSM_PIN_COUNT];
  
  int inCommand;
  
  int serialState;
  int serialNumber;
  int serialLastValue;
  
  int exposureNameIndex;
  
  unsigned long lastActivation[DSM_PIN_COUNT];

};

#endif

