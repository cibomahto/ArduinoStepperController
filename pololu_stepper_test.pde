
#include "commands.h"
#include "stepper.h"

void handler( CommandInterpreter::Message *msg );


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
    case M_GETPOS:
      handleGETPOS(msg->fields[0]);
      break;
    case M_SET:
      commander.sendERROR("SET not supported in this firmware");
      break;
    case M_GET:
      commander.sendERROR("GET not supported in this firmware");
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
  if ( axis >= Stepper::count()) {
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

void handleGETPOS(uint8_t axis) {
  if ( axis >= Stepper::count()) {
    commander.sendERROR("Axis out of bounds");
  }
  
  long position = Stepper::getStepper(axis).getPosition();
  char buffer[50];
  sprintf(buffer, "GETPOS %d %ld", axis, position);
  
  commander.sendACK(buffer);
}

void handleSTATE() {
  // Try to determine the state... we don't support ERROR or HOMING, so it has
  // to be READY or GOING
  boolean isMoving = false;

  for ( uint8_t axis = 0; axis < Stepper::count(); axis++) {
    if (Stepper::getStepper(axis).isMoving()) {
      isMoving = true;
    }
  }
  
  if ( isMoving ) {
    commander.sendACK("STATE GOING");
  }
  else {
    commander.sendACK("STATE READY");
  }
}

void setup() {
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
  // The display is updated in the interrupt routine
  TCCR2A = 0;
  TCCR2B = (0<<CS22)|(1<<CS21)|(0<<CS20);
  TIMSK2 = (1<<TOIE2);

  // Setup the command handler function
  commander.begin(9600);
  
//  commander.setCommandHandler( handler );
}

void loop() {
  
  commander.checkSerialInput();
  
}
