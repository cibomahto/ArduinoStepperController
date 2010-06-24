
#include "commands.h"
#include "stepper.h"
#include <EEPROM.h>
#include "EEPROM_templates.h"


void handler( CommandInterpreter::Message *msg );

#define statusLED 13

#define eepromLocation 0

// Settings that can persist over reboots
struct driverSettings {
  char magicCode[3];    // Should be 'meh', or the EEPROM is invalid
  long index;
};

driverSettings settings;

// This is the version number reported from the GET VERSION command
const long versionNumber = 1;



// These are the locations of the stepper drivers, using Matts Pololu breakout shield:
// http://www.cibomahto.com/2010/06/one-shield-to-fit-them-all-and-in-the-darkness-bind-them/
Stepper stepperA(10, 11, 12);
Stepper stepperB(14, 15, 16);
Stepper stepperC(7, 8, 9);
Stepper stepperD(17, 18, 19);

CommandInterpreter commander(handler);

  
void handler( CommandInterpreter::Message *msg ) {
  switch (msg->type) {
    case M_GO:
      handleGO(msg->fields[0], msg->fields[1], msg->fields[2]);
      break;
    case M_SET:
      handleSET(msg->fields[0], msg->fields[1], msg->fields[2]);
      break;
    case M_GET:
      handleGET(msg->fields[0], msg->fields[1]);
      break;
    case M_HOME:
      commander.sendERROR("HOME not supported in this firmware");
      break;
    case M_STATE:
      handleSTATE();
      break;
  }
}


void handleGO(uint8_t axis, long position, long time) {
  if ( axis >= Stepper::count() ) {
    commander.sendERROR("Axis out of bounds");
  }
  
  if (Stepper::getStepper(axis).moveAbsolute(position, time)) {
    char buffer[50];
    sprintf(buffer, "GO %d %ld %ld", axis, position, time);
    commander.sendACK(buffer);
  }
  else {
    // TODO: Give a better reason here?
    commander.sendERROR("Couldn't acheive desired motion");
  }
}


void handleGET(uint8_t parameterName, uint8_t axis) {
  if ( axis >= Stepper::count() ) {
    commander.sendERROR("parameter axis out of bounds");
    return;
  }
  
  char buffer[50];
  boolean good = false;
  switch (parameterName) {
    case P_VERSION:
      sprintf(buffer, "GET VERSION %ld", versionNumber);
      good = true;
      break;
    case P_INDEX:
      sprintf(buffer, "GET INDEX %ld", settings.index);
      good = true;
      break;
    case P_MAX_VEL:
     {
      long velocity = Stepper::getStepper(axis).getMaxVelocity();
      sprintf(buffer, "GET MAX_VEL %d %ld", axis, velocity);
      good = true;
     }
      break;
    case P_ACCEL:
     {
      long acceleration = Stepper::getStepper(axis).getPosition();
      sprintf(buffer, "GET ACCEL %d %ld", axis, acceleration);
      good = true;
     }
      break;
    case P_POS:
     {
      long position = Stepper::getStepper(axis).getPosition();
      sprintf(buffer, "GET POS %d %ld", axis, position);
      good = true;
     }
      break;
  }
  
  if (good) {
    commander.sendACK(buffer);
  }
  else {
    commander.sendERROR("invalid parameter");
  }
}


void handleSET(uint8_t parameterName, long value1, long value2) {  
  // TODO: Don't allow anything to be set while in motion?
  
  char buffer[50];
  boolean good = false;
  switch (parameterName) {
    case P_VERSION:
      commander.sendERROR("Can't change the version number!");
      return;
      break;
    case P_INDEX:
      settings.index = value2;
      saveSettings();
      sprintf(buffer, "SET INDEX %ld", settings.index);
      good = true;
      break;
    case P_MAX_VEL:
      if ( value1 >= Stepper::count() || value1 < 0 ) {
        commander.sendERROR("parameter axis out of bounds");
        return;
      }
      good = Stepper::getStepper(value1).setMaxVelocity(value2);
      
      if ( good ) {
        sprintf(buffer, "SET MAX_VEL %ld %ld", value1, value2);
      }
      break;
    case P_ACCEL:
      if ( value1 >= Stepper::count() || value1 < 0 ) {
        commander.sendERROR("parameter axis out of bounds");
        return;
      }
      good = Stepper::getStepper(value1).setAcceleration(value2);
      
      if ( good ) {
        sprintf(buffer, "SET ACCEL %ld %ld", value1, value2);
      }
      break;
    case P_POS:
      if ( value1 >= Stepper::count() || value1 < 0 ) {
        commander.sendERROR("parameter axis out of bounds");
        return;
      }
      good = Stepper::getStepper(value1).setPosition(value2);
      
      if ( good ) {
        sprintf(buffer, "SET POS %ld %ld", value1, value2);
      }
      break;
  }
  
  if (good) {
    commander.sendACK(buffer);
  }
  else {
    commander.sendERROR("invalid parameter");
  }
}




void handleSTATE() {
  // Try to determine the state... we don't support ERROR or HOMING, so it has
  // to be READY or GOING
  boolean busy = false;

  for ( uint8_t axis = 0; axis < Stepper::count(); axis++) {
    if (Stepper::getStepper(axis).busy()) {
      busy = true;
    }
  }
  
  if ( busy ) {
    commander.sendACK("STATE GOING");
  }
  else {
    commander.sendACK("STATE READY");
  }
}


void restoreSettings() {
  int offset = 0;
  offset += EEPROM_readAnything(eepromLocation, settings);

  // Check that the magic code is correct!
  if ( strncmp( settings.magicCode, "meh", 3) != 0) {
//    Serial.print("Invalid EEPROM settings, resetting\n");
    // Pack some sane default settings into the structure, and save
    settings.magicCode[0] = 'm';
    settings.magicCode[1] = 'e';
    settings.magicCode[2] = 'h';
    settings.index = 0;

    saveSettings();
  }
  else {
    // TODO: restore settings for the steppers
  }
}

void saveSettings() {
  int offset = 0;
  offset += EEPROM_writeAnything(eepromLocation, settings);

  // TODO: write settings from the steppers
}

void setup() {
  pinMode(statusLED, OUTPUT);
  
  restoreSettings();

  Stepper::setup(0);

  // TODO: Move this to stepper
  
  /*
 * 0 0 1 clkT2S/(No prescaling)
 * 0 1 0 clkT2S/8 (From prescaler)
 * 0 1 1 clkT2S/32 (From prescaler)
 * 1 0 0 clkT2S/64 (From prescaler)
 * 1 0 1 clkT2S/128 (From prescaler)
 * 1 1 0 clkT2S/256 (From prescaler)
 * 1 1 1 clkT2S/1024 (From prescaler)
*/

  // Set up Timer 2 to generate interrupts on overflow, and start it.
  // The stepper output routine is updated in the interrupt
  
  // Use CTC mode
//  TCCR2A = (1<<WGM22)|(1<<WGM21)|(1<<WGM20);
  TCCR2A = _BV(WGM21);
  
  // Set the timer to use the clkT2S/8 as the clock source
  TCCR2B = (0<<CS22)|(1<<CS21)|(0<<CS20);
  
  // and set the top to ??, to generate a 10KHz wave
  OCR2A = 198;
  
  // Finally, enable the interrupt
  TIMSK2 = (1<<OCIE2A);

  // Setup the command handler function
  commander.begin(9600);

  digitalWrite(statusLED, true);
}


char buff[25];

void loop() {  
  commander.checkSerialInput();

  for ( uint8_t axis = 0; axis < Stepper::count(); axis++) {  
    if ( Stepper::getStepper(axis).checkFinished() ) {
      sprintf(buff, "DONE %d", axis);
      commander.sendNOTICE(buff);
    }
  }
}
