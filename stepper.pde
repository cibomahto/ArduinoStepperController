#include "stepper.h"

// This function is called when timer2 overflows
ISR(TIMER2_OVF_vect)
{ 
  Stepper::doStepperInterrupts();
}


uint8_t Stepper::stepperCount = 0;

Stepper* registeredSteppers[MAX_STEPPERS];


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

Stepper& Stepper::getStepper(const int index) {
  // TODO: Test for validity here?
  // if ( index < 0 || index >= stepperCount )
  return *registeredSteppers[index];
}
  

Stepper::Stepper(uint8_t resetPin_, uint8_t stepPin_, uint8_t directionPin_) {
  resetPin = resetPin_;
  stepPin = stepPin_;
  directionPin = directionPin_;
  running = false;

  pinMode(resetPin, OUTPUT);
  pinMode(stepPin, OUTPUT);
  pinMode(directionPin, OUTPUT);

  doReset();

  registerStepper(this);
}

void Stepper::doReset() {
  position = 0;

  digitalWrite(directionPin, LOW);
  digitalWrite(stepPin, LOW);

  digitalWrite(resetPin, LOW);
  digitalWrite(resetPin, HIGH);
}

boolean Stepper::moveAbsolute(long newPosition, long ticks) {
  return moveRelative(newPosition - position, ticks);
}

boolean Stepper::moveRelative(long counts, long ticks) {
  
  if (counts > ticks || ticks == 0) {
    return false;
  }
  
  if ( counts > 0) {
    digitalWrite(directionPin, HIGH);
    direction = 1;
  }
  else {
    digitalWrite(directionPin, LOW);
    direction = -1;
  }

  countsLeft = abs(counts);

  deltax = ticks;
  deltay = abs(counts);  
  error = deltax / 2;
  
  running = true;
  
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
  if (running) {
//  Serial.print("countsLeft=");
//  Serial.print(countsLeft);

//  Serial.print(" ticsPerCount=");
//  Serial.print(ticksPerCount);
  
//  Serial.print(" nextTick=");
//  Serial.print(nextTick);
  
//  Serial.print("\n\r");

    error = error - deltay;
    if (error < 0) {
      // Do movement
      digitalWrite(stepPin, HIGH);
      digitalWrite(stepPin, LOW);
  
      // Update counters
      position += direction;
      countsLeft--;
      
      error = error + deltax;
      
      if (countsLeft == 0) {
        running = false;
      } 
    }
  }
}


long Stepper::getPosition() {
  return position;
}

