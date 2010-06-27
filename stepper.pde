#include "stepper.h"
#include "EEPROM_templates.h"
#include <EEPROM.h>

#define signalPin 2


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
  digitalWrite(signalPin, HIGH);
  Stepper::doStepperInterrupts();
  digitalWrite(signalPin, LOW);
}


uint8_t Stepper::stepperCount = 0;
unsigned int Stepper::frequency = 0;

Stepper* registeredSteppers[MAX_STEPPERS];

void Stepper::setup(unsigned int frequency_) {
  
  pinMode(signalPin, OUTPUT);

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
    size += EEPROM_readAnything(offset + size, registeredSteppers[i]->settings);
  }
  
  return size;
}

Stepper::Stepper(uint8_t resetPin_, uint8_t stepPin_, uint8_t directionPin_) :
  resetPin(resetPin_),
  stepPin(stepPin_),
  directionPin(directionPin_)
{
  pinMode(resetPin, OUTPUT);
  pinMode(stepPin, OUTPUT);
  pinMode(directionPin, OUTPUT);

  doReset();

  registerStepper(this);
}



void Stepper::doReset() {
  moving = false;
  finished = false;
  
  position = 0;

  digitalWrite(directionPin, LOW);
  digitalWrite(stepPin, LOW);


  if ( settings.stopMode == S_DISABLE ) {
    // TODO: Use enable pin instead of reset pin
    digitalWrite(resetPin, HIGH);
  }
}

boolean Stepper::moveAbsolute(long newPosition, long& time) {
  return moveRelative(newPosition - position, time);
}

boolean Stepper::moveRelative(long steps, long& time) {
  long frequency = 10000;  // Frequency, in Hz
  long ticks;
  
  if ( moving ) {
    return false;
  }

  if (steps == 0) {
    finished = true;
    return true;
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
    // TODO: Use enable pin instead of reset pin
    digitalWrite(resetPin, LOW);
  }
  
  moving = true;
  
  return true;
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
  if (moving) {
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
        moving = false;
        finished = true;
        
        if (settings.stopMode = S_DISABLE) {
          digitalWrite(resetPin, HIGH);
        }
      } 
    }
  }
}


long Stepper::getPosition() {
  return position;
}

boolean Stepper::setPosition(long position_) {
  if (moving) {
    return false;
  }
   
  position = position_;
  return true;
}

long Stepper::getMaxVelocity() {
  return settings.maxVelocity;
}

boolean Stepper::setMaxVelocity(long velocity_) {
  if (moving) {
    return false;
  }
   
  settings.maxVelocity = velocity_;
  return true;
}

long Stepper::getAcceleration() {
  return settings.acceleration;
}

boolean Stepper::setAcceleration(long acceleration_) {
  if (moving) {
    return false;
  }
   
  settings.acceleration = acceleration_;
  return true;
}

STOP_MODES Stepper::getStopMode() {
  return settings.stopMode;
}

boolean Stepper::setStopMode(STOP_MODES stopMode_) {
if (moving) {
    return false;
  }
   
  settings.stopMode = stopMode_;

  // Update the output if we changed modes
  switch (settings.stopMode) {
    case S_DISABLE:
      digitalWrite(resetPin, HIGH);
      break;
    case S_KEEP_ENABLED:
      digitalWrite(resetPin, LOW);
      break;
  }
  
  return true;
}

boolean Stepper::checkFinished() {
  if (finished) {
    finished = false;
    return true;
  }
  
  return false;
}

boolean Stepper::busy() {
  return moving;
}

