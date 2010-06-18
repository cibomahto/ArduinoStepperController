
#include "commands.h"
#include "stepper.h"


// This code assumes that we have one stepper attached,  with:
// reset pin=10, step pin=11, direction pin=12
Stepper stepperA(10, 11, 12);

// These are the possible locations of other steppers, using Matts Pololu breakout shield:
// http://www.cibomahto.com/2010/06/one-shield-to-fit-them-all-and-in-the-darkness-bind-them/
Stepper stepperB(14, 15, 16);
Stepper stepperC(7, 8, 9);
Stepper stepperD(17, 18, 19);


void setup() {
  Serial.begin(9600);

  // Setup the command handler function
  setCommandHandler( handler );

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
  // TODO: Move this to stepper
  TCCR2A = 0;
  TCCR2B = (0<<CS22)|(1<<CS21)|(0<<CS20);
  TIMSK2 = (1<<TOIE2);
}

void error( char* message ) {
  Serial.print("ERROR ");
  Serial.print(message);
  Serial.print("\n");
}

void ack() {
  ack ("");

}

void ack( char* message ) {
  Serial.print("ACK ");
  Serial.print(message);
  Serial.print("\n");
}
  
  
void handler( struct Message *msg ) {

/*
  Serial.print("\n\r");
  Serial.print("DEBUG MESSAGE_RECEIVED type=");
  Serial.print(msg->type);
  Serial.print(" fields=(");
  Serial.print(msg->fields[0]);
  Serial.print(", ");
  Serial.print(msg->fields[1]);
  Serial.print(", ");
  Serial.print(msg->fields[2]);
  Serial.print(", ");
  Serial.print(msg->fields[3]);
  Serial.print(")\n");
*/
  
  switch (msg->type) {
    case M_GO:
      handleGO(msg->fields[0], msg->fields[1], msg->fields[2]);
      break;
    case M_GETPOS:
      handleGETPOS(msg->fields[0]);
      break;
    case M_SET:
    case M_GET:
    case M_HOME:
    case M_STATE:
    default:
      // Really we should never reach this.
      error("Message not understood");
  }
}

void handleGO(uint8_t axis, long position, long time) {
  if ( axis >= Stepper::count()) {
    error("Axis out of bounds");
  }
  
  if (Stepper::getStepper(axis).moveAbsolute(position, time)) {
    ack();
  }
  else {
    // TODO: Give a better reason here?
    error("Couldn't acheive desired motion");
  }
}

void handleGETPOS(uint8_t axis) {
  if ( axis >= Stepper::count()) {
    error("Axis out of bounds");
  }
  
  long position = Stepper::getStepper(axis).getPosition();
  char buffer[50];
  sprintf(buffer, "GETPOS %d %ld", axis, position);
  
  ack(buffer);
}


char buf[256];
struct Message msg;

void loop() {
  
  checkSerialInput();
  
}
