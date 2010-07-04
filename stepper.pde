#include "stepper.h"
#include "EEPROM_templates.h"
#include <EEPROM.h>


#if defined(__AVR_ATmega8__) || \
    defined(__AVR_ATmega48__) || \
    defined(__AVR_ATmega88__) || \
    defined(__AVR_ATmega168__) || \
    defined(__AVR_ATmega328P__)

// This function is called when timer2 overflows
ISR(TIMER2_COMPA_vect)

#elif defined(__AVR_ATmega1280__) 

// This function is called when timer2 overflows
ISR(TIMER1_COMPA_vect)

#endif

{ 
  Stepper::doStepperInterrupts();
}


uint8_t Stepper::stepperCount = 0;
unsigned int Stepper::frequency = 0;

Stepper* registeredSteppers[MAX_STEPPERS];

void Stepper::setup(unsigned int frequency_) {

  // TODO: actually set up the timer using the given frequency
  
  frequency = frequency_;
}

boolean Stepper::registerStepper(Stepper* stepper_) {
  if ( stepperCount >= MAX_STEPPERS ) {
    return false;
  }
    
  registeredSteppers[stepperCount] = stepper_;
  stepperCount++;
  
  return true;
}


void Stepper::doStepperInterrupts() {
  for (uint8_t i = 0; i < stepperCount; i++) {
    registeredSteppers[i]->doInterrupt();
  }
}

uint8_t Stepper::count() {
  return stepperCount;
}

boolean Stepper::indexValid(const int index) {
  return (index > 0 && index <= stepperCount);
}

Stepper& Stepper::getStepper(const int index) {
  // TODO: Test for out-of-bounds here?
  // if ( index < 0 || index >= stepperCount )
  return *registeredSteppers[index - 1];
}

int Stepper::saveSettings(int offset) {
  int size = 0;
  
  for (uint8_t i = 0; i < stepperCount; i++) {
    size += EEPROM_writeAnything(offset + size, registeredSteppers[i]->settings);
  }
  
  return size;
}
int Stepper::restoreSettings(int offset) {
  int size = 0;
  
  for (uint8_t i = 0; i < stepperCount; i++) {
    // Read the settings in, then apply them
    size += EEPROM_readAnything(offset + size, registeredSteppers[i]->settings);
    registeredSteppers[i]->doReset();
  }
  
  return size;
}  

Stepper::Stepper(uint8_t enablePin_, uint8_t stepPin_, uint8_t directionPin_, uint8_t limitPin_) :
  enablePin(enablePin_),
  stepPin(stepPin_),
  directionPin(directionPin_),
  limitPin(limitPin_),
  // TODO: Don't support homing by default
  settings(200, 0, S_DISABLE, H_BACKWARD, true)
{
  pinMode(enablePin, OUTPUT);
  pinMode(stepPin, OUTPUT);
  pinMode(directionPin, OUTPUT);
  pinMode(limitPin, INPUT);
  digitalWrite(limitPin, LOW );    // disable the pull-up resistor
  
  doReset();

  registerStepper(this);
}


void Stepper::doReset() {
  state = S_READY;
  
  position = 0;

  digitalWrite(directionPin, LOW);
  digitalWrite(stepPin, LOW);


  if ( settings.stopMode == S_DISABLE ) {
    digitalWrite(enablePin, HIGH);
  }
}

boolean Stepper::moveAbsolute(long newPosition, long& time) {
  return moveRelative(newPosition - position, time);
}

boolean Stepper::moveRelative(long steps, long& time) {
  long frequency = 10000;  // Frequency, in Hz
  long ticks;
  
  // If we are already doing something, don't start a new motion
  if ( busy() ) {
    return false;
  }

  // If we are already there, don't bother moving
  if (steps == 0) {
    state = S_FINISHED_MOVING;
    return true;
  }
  
  // Check if we are at a limit, and only move if we can
  if( settings.canHome && digitalRead(limitPin) == LOW) {
    if ( steps < 0 && settings.homeDirection == H_BACKWARD ||
         steps > 0 && settings.homeDirection == H_FORWARD ) {
      return false;
    }
  }
  
  // If the requested speed is too fast, set it to a speed we can achieve
  if ( time <= 0 ||
       ((float)abs(steps) / time ) * 1000 > settings.maxVelocity ) {
    time = ((float)abs(steps) * 1000) / settings.maxVelocity;
  }
  
  // Calculate how many ticks the operation should last
  // ticks(steps) = frequency (steps/s) * time (ms) / 1000 (s/ms)
  ticks = (float)frequency * time / 1000;
  
  if ( steps > 0) {
    digitalWrite(directionPin, HIGH);
    direction = 1;
  }
  else {
    digitalWrite(directionPin, LOW);
    direction = -1;
  }

  stepsLeft = abs(steps);

  deltax = ticks;
  deltay = abs(steps);
  error = deltax / 2;

  if ( settings.stopMode = S_DISABLE ) {
    digitalWrite(enablePin, LOW);
  }
  
  state = S_MOVING;
  
  return true;
}

boolean Stepper::home() { 
 if ( busy() ) {
    return false;
  }
  
  boolean canMove;
  
  long time = 0;
  
  // just walk, in the hope that we get somewhere
  if ( settings.homeDirection == H_BACKWARD ) {
    canMove = moveRelative((long)-11000, time);
  }
  else {
    canMove = moveRelative((long)11000, time);
  }

  if (canMove == true) {
    state = S_HOMING_A;
  }
  
  return canMove;
}

/*
 function line(x0, x1, y0, y1)
     int deltax := x1 - x0
     int deltay := abs(y1 - y0)
     int error := deltax / 2
     int ystep
     int y := y0
     if y0 < y1 then ystep := 1 else ystep := -1
     for x from x0 to x1
         if steep then plot(y,x) else plot(x,y)
         error := error - deltay
         if error < 0 then
             y := y + ystep
             error := error + deltax
*/


void Stepper::doInterrupt() {
  // Only run the interrupt if we are moving
  if (state != S_MOVING && state != S_HOMING_A && state != S_HOMING_B) {
    return;
  }
  
  bool doneMoving = false;
  
  // Check if we just walked into the limit switch
  if( settings.canHome && digitalRead(limitPin) == LOW ) {
    if ( ( direction < 0 && settings.homeDirection == H_BACKWARD ) ||
         ( direction > 0 && settings.homeDirection == H_FORWARD ) )
    {
      // Respond to the switch based on the state we are in
      switch (state) {
        case S_HOMING_A:
          // We got to the first part of the pattern, now walk back out until we don't see the switch any more
          state = S_HOMING_B;
          direction = -direction;
          
          if (direction = 1) {
            digitalWrite(directionPin, HIGH);
          }
          else {
            digitalWrite(directionPin, LOW);
          }
          
          break;
        case S_MOVING:
          // Oops, we hit a limit!
          // TODO: error here.
          // state = S_ERROR;
          state = S_FINISHED_MOVING;
          doneMoving = true;
          break;
        case S_HOMING_B:
          // Fall through to the moving code
          break;
      }
    }
  }
  // We didn't hit a limit switch, so check if we were trying to move away from it
  else if ( state == S_HOMING_B ) {
    // We got back to a place with no limit switch, so we are done!
    state = S_FINISHED_HOMING;
    doneMoving =  true;
    position = 0;
  }
  
  // If we are still moving, do so
  if (!doneMoving) {
    error = error - deltay;
    if (error < 0) {
      // Do movement
      digitalWrite(stepPin, HIGH);
      digitalWrite(stepPin, LOW);
  
      // Update counters
      position += direction;
      stepsLeft--;
      
      error = error + deltax;
      
      if (stepsLeft == 0) {
        state = S_FINISHED_MOVING;
    
        doneMoving =  true;
      }
    }
  }
  
  // Stopping motion tasks
  if (doneMoving) {
    if (settings.stopMode = S_DISABLE) {
      digitalWrite(enablePin, HIGH);
    }
  }
}


long Stepper::getPosition() {
  return position;
}

boolean Stepper::setPosition(long position_) {
  if ( busy() ) {
    return false;
  }
   
  position = position_;
  return true;
}

long Stepper::getMaxVelocity() {
  return settings.maxVelocity;
}

boolean Stepper::setMaxVelocity(long velocity_) {
  if ( busy() ) {
    return false;
  }
   
  settings.maxVelocity = velocity_;
  return true;
}

long Stepper::getAcceleration() {
  return settings.acceleration;
}

boolean Stepper::setAcceleration(long acceleration_) {
  if ( busy() ) {
    return false;
  }
   
  settings.acceleration = acceleration_;
  return true;
}

STOP_MODES Stepper::getStopMode() {
  return settings.stopMode;
}

boolean Stepper::setStopMode(STOP_MODES stopMode_) {
if ( busy() ) {
    return false;
  }
   
  settings.stopMode = stopMode_;

  // Update the output if we changed modes
  switch (settings.stopMode) {
    case S_DISABLE:
      digitalWrite(enablePin, HIGH);
      break;
    case S_KEEP_ENABLED:
      digitalWrite(enablePin, LOW);
      break;
  }
  
  return true;
}

boolean Stepper::checkFinished() {
  if (state == S_FINISHED_MOVING) {
    state = S_READY;
    return true;
  }
  else if (state == S_FINISHED_HOMING) {
    state = S_READY;
    return true;
  }
  
  return false;
}

boolean Stepper::busy() {
  return !(state == S_READY);
}

