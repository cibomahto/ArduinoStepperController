

//ADDED FOR COMPATIBILITY WITH WIRING
extern "C" {
  #include <stdlib.h>
}

#include "DragonStopMotion.h"
#include "WProgram.h"

#define STATE_START     0
#define STATE_CH1       1
#define STATE_PREFRAME  2
#define STATE_FRAME     3
#define STATE_EXP       4
#define STATE_EXP_NAME  5
#define STATE_EXP_STER  6


DragonStopMotion::DragonStopMotion(HardwareSerial& port_) :
    port(port_)
{
	uint8_t i;
	for (i = 0; i < DSM_PIN_COUNT; i++)
	{
		command[i] = 0;
		logicActive[i] = 0;
		arg[i] = 0;
		value[i] = 0;
		lastActivation[i] = 0;
	}

	serialState = 0;
	serialNumber = 0;
	serialLastValue = 0;
	
	inCommand = 0;
	commandFrame = 0;
	commandExposure = 0;
	commandStereoPosition = 0;
}

void DragonStopMotion::activatePin(int pin, int val, int command)
{
	activatePin(pin, val, command, 0);
}

void DragonStopMotion::activatePin(int pin, int val, int command, int arg)
{
	if (pin < 0 || pin >= DSM_PIN_COUNT)
		return;

	pinMode(pin, INPUT);
	
	this->command[pin] = command;
	this->arg[pin] = arg;
	
	this->logicActive[pin] = val;
	this->value[pin] = digitalRead(pin);
}

void DragonStopMotion::deactivatePin(int pin)
{
	if (pin < 0 || pin >= DSM_PIN_COUNT)
		return;

	command[pin] = 0;
}

void DragonStopMotion::shootFrame(int frames)
{
	port.print("S ");
	port.print(frames);
	port.print("\r\n");
}

void DragonStopMotion::deleteFrame()
{
	port.print("D\r\n");
}

void DragonStopMotion::togglePlay()
{
	port.print("P\r\n");
}


void DragonStopMotion::goToLive()
{
	port.print("L\r\n");
}


void DragonStopMotion::processPins()
{
	uint8_t pin;
	unsigned long now;
	unsigned long delta;
	
	now = millis();

	for ( pin = 0; pin < DSM_PIN_COUNT; pin++ )
	{
		if (command[pin])
		{
			int v = digitalRead(pin);
			if (v != value[pin])
			{
				value[pin] = v;
				if (v == logicActive[pin])
				{
					if (now > lastActivation[pin])
					{
						delta = now - lastActivation[pin];
						if (delta < 500)
						{
							continue;
						}
					}
					lastActivation[pin] = now;
					switch (command[pin])
					{
						case DRAGON_SHOOT_CMD:
							shootFrame(arg[pin]);
							break;
						
						case DRAGON_DELETE_CMD:
							deleteFrame();
							break;

						case DRAGON_PLAY_CMD:
							togglePlay();
							break;

						case DRAGON_LIVE_CMD:
							goToLive();
							break;
					}
				}
			}
		}
	}
}

int DragonStopMotion::processSerial()
{
	if (port.available() > 0)
	{
		int inByte = port.read();
		
		if (inByte == '\n' && serialLastValue == '\r')
		{
			if (serialState == STATE_EXP_STER)
			{
				commandStereoPosition = serialNumber;
			}
		
			serialState = STATE_START;
			return inCommand;
		}
		if (serialState == STATE_START)
		{
			inCommand = 0;
			commandFrame = 0;
			commandExposure = 0;
			exposureNameIndex = 0;
			commandExposureName[0] = 0;
			
			serialState = STATE_CH1;
		}
		else if (serialState == STATE_CH1)
		{
			if (serialLastValue == 'S' && inByte == 'H')
			{
				inCommand = DRAGON_SHOOT_MSG;
				serialState = STATE_PREFRAME;
				serialNumber = 0;
			}
			else if (serialLastValue == 'D' && inByte == 'E')
			{
				inCommand = DRAGON_DELETE_MSG;
			}
			else if (serialLastValue == 'P' && inByte == 'F')
			{
				inCommand = DRAGON_POSITION_MSG;
				serialState = STATE_PREFRAME;
				serialNumber = 0;
			}
			else if (serialLastValue == 'C' && inByte == 'C')
			{
				inCommand = DRAGON_CC_MSG;
				serialState = STATE_PREFRAME;
				serialNumber = 0;
			}
			else
			{
				serialState = STATE_START;
			}
		}
		else if (serialState == STATE_PREFRAME)
		{
			if (inByte == ' ')
				serialState = STATE_FRAME;
			else
			{
				inCommand = 0;
				serialState = STATE_START;
			}
		}
		else if (serialState == STATE_FRAME)
		{
			if (inByte == ' ')
			{
				serialState = STATE_EXP;
				commandFrame = serialNumber;
				serialNumber = 0;
			}
			else if (inByte >= '0' && inByte <= '9')
			{
				serialNumber = (10 * serialNumber) + (inByte - '0');
			}
		}
		else if (serialState == STATE_EXP)
		{
			if (inByte == ' ')
			{
				serialState = STATE_EXP_NAME;
				commandExposure = serialNumber;
				serialNumber = 0;
			}
			else if (inByte >= '0' && inByte <= '9')
			{
				serialNumber = (10 * serialNumber) + (inByte - '0');
			}
		}
		else if (serialState == STATE_EXP_NAME)
		{
			if (inByte == ' ')
			{
				serialState = STATE_EXP_STER;
				serialNumber = 0;
			}
			else if (exposureNameIndex < DRAGON_EXP_NAME_LENGTH)
			{
				commandExposureName[exposureNameIndex] = inByte;
				exposureNameIndex++;
				commandExposureName[exposureNameIndex] = 0;
			}
		}
		else if (serialState == STATE_EXP_STER)
		{
			if (inByte >= '0' && inByte <= '9')
			{
				serialNumber = (10 * serialNumber) + (inByte - '0');
			}
		}
		
		serialLastValue = inByte;
	}
	return 0;
}



