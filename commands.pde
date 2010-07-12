/*
 * Documenting our discussion [literals in all caps, variables in lowercase]:
 * Changes/clarifications?
 * All messages are terminated by '\n' NOT '\0'
 * 
 * GO axis position time
 * ACK GO axis position time
 * DONE axis
 * 
 * GO Tells the controller to move AXIS to POSITION taking TIME miliseconds to get there
 * ACK is sent by the controller immediately after GO recvd.  POSITION and TIME may be modified if POSITION was out of range or TIME was too short.
 * NOTICE DONE is sent when the move completes
 * 
 * STOP Tells the controller to stop the motion of all axis immediately
 * ACK is sent by the controller immediately after DONE recvd.
 * NOTICE DONE will be recieved on any axis that were moving
 *
 * SET param value
 * ACK SET param value
 * Sets PARAM to VALUE.  Valid PARAMs are: VERSION, INDEX, MAX_VELOCITY, ACCEL, POS
 * 
 * GET param value
 * ACK GET param value
 * Gets the current VALUE of PARAM.
 * 
 * HOME axis
 * ACK HOME axis
 * NOTICE DONE axis
 * Executes homing procedure for the specified AXIS.  DONE is sent when homing completes.
 * 
 * STATE
 * ACK STATE state
 * 
 * Queries current state.  state = [READY, ERROR, GOING, HOMING]
 * 
 * ERROR msg
 * ERROR is sent by the controller when something bad happens.  msg described what happened
 *
 * ALIVE
 * ACK ALIVE
 *
 * Confirm that the controller is alive and accepting input
 *
 * CLICK
 * ACK CLICK
 *
 * Send a click to the camera, which is on the second serial port
 *
 
*/


#include "commands.h"

#include <stdlib.h>
#include <ctype.h>


#include <HardwareSerial.h>

// TODO: Fill out num_values here?
CommandInterpreter::ParameterDefinition CommandInterpreter::parameterTypes[] = {
  { "VERSION",  P_VERSION,      false },    // Interface version (read only)
  { "INDEX",    P_INDEX,        false },    // Programmable device name for this specific board
  { "MAX_VEL",  P_MAX_VEL,      true },
  { "ACCEL",    P_ACCEL,        true },
  { "STOP_MODE",P_STOP_MODE,    true },
  { "POS",      P_POS,          true },
  { NULL,       NOT_A_PARAMETER },
};


CommandInterpreter::MessageTypeDefinition CommandInterpreter::messageTypes[] = {
  { "GO",     M_GO         , GO_VALUES  },    // GO axis position time
  { "STOP",   M_STOP       , NO_VALUES  },    // STOP
  { "GET",    M_GET        , GET_VALUES },    // GET param axis
  { "HOME",   M_HOME       , HOME_VALUES  },  // HOME axis
  { "STATE",  M_STATE      , NO_VALUES  },    // STATE
  { "ALIVE",  M_ALIVE      , NO_VALUES  },    // ALIVE
  { "CLICK",  M_CLICK      , NO_VALUES  },    // Send a 'click' to the camera
  { NULL,  NOT_A_MESSAGE, NULL },
};

CommandInterpreter::MESSAGE_VALUE_TYPE CommandInterpreter::NO_VALUES[]     = {NOT_A_VALUE};
CommandInterpreter::MESSAGE_VALUE_TYPE CommandInterpreter::GO_VALUES[]     = {MT_INTEGER, MT_INTEGER, MT_INTEGER, NOT_A_VALUE};
CommandInterpreter::MESSAGE_VALUE_TYPE CommandInterpreter::SET_VALUES[]    = {MT_PARAM_NAME, MT_INTEGER, MT_INTEGER, NOT_A_VALUE};
CommandInterpreter::MESSAGE_VALUE_TYPE CommandInterpreter::GET_VALUES[]    = {MT_PARAM_NAME, MT_INTEGER, NOT_A_VALUE};
CommandInterpreter::MESSAGE_VALUE_TYPE CommandInterpreter::HOME_VALUES[]   = {MT_INTEGER, NOT_A_VALUE};


CommandInterpreter::CommandInterpreter(CommandHandler handler) : 
  commandBufIdx(0),
  cmdHandler(handler)
{
}


void CommandInterpreter::begin(unsigned int baudrate)
{
  Serial.begin(baudrate);
}

void CommandInterpreter::sendERROR( const char* message ) {
  Serial.print("ERROR ");
  Serial.print(message);
  Serial.print("\n");
}


void CommandInterpreter::sendACK( const char* message ) {
  Serial.print("ACK ");
  Serial.print(message);
  Serial.print("\n");
}


void CommandInterpreter::sendNOTICE( const char* message ) {
  Serial.print("NOTICE ");
  Serial.print(message);
  Serial.print("\n");
}

void CommandInterpreter::sendDONE( const char* message ) {
  Serial.print("DONE ");
  Serial.print(message);
  Serial.print("\n");
}

//returns the index of the character after the last charater in the message type or -1
//sets msg->type and msg->typeDefIdx
int CommandInterpreter::parseCmdType( const char *cmd, Message& msg ) {
  int i=0;
  while( messageTypes[i].name != NULL ) {
    if( strncmp( cmd, messageTypes[i].name, strlen(messageTypes[i].name) ) == 0 ) {
      msg.type = messageTypes[i].type;
      msg.typeDefIdx = i;
      return strlen(messageTypes[i].name);
    }
    i++;
  }
 
  sendERROR( "message had unknown prefix" );
  msg.type = NOT_A_MESSAGE;
  return -1;
}

// TODO: Make this signature match with parseCmdType()
PARAMETER CommandInterpreter::parseParamName( const char *name, boolean& requiresAxis ) {
  int i=0;
  while( parameterTypes[i].name != NULL ) {
    if( strncmp( name, parameterTypes[i].name, sizeof(parameterTypes[i].name)) == 0 ) {
      
      requiresAxis = parameterTypes[i].requiresAxis;
      return parameterTypes[i].param;
    }
    i++;
  }

  return NOT_A_PARAMETER;
}

//pre: msg->type is the type of message in cmd
//post: msg->fields is filled in or non-zero is returned
boolean CommandInterpreter::parseMessageValues( const char *str, Message& msg ) {
  int strIdx = 0;
  int valIdx = 0;
 
  // Look up the type of message we are dealing with, so we know what set of inputs to
  // look for (integers, parameter names, etc)
  MessageTypeDefinition& mt = messageTypes[msg.typeDefIdx];
  
  // While we are still expecting more input
  while( mt.values[valIdx] != NOT_A_VALUE ) {
    //advance past leading whitespace
    while( isspace( str[strIdx]) && str[strIdx] != 0 )  strIdx++;
    
    switch( mt.values[valIdx] ) {
      // If it is an integer, read it in as a signed long
      case MT_INTEGER:
        if( 1 != sscanf( str + strIdx, "%ld", &msg.fields[valIdx] ) )
          goto PARSE_ERROR;
        break;
      // If it is a parameter name, read it in as a string
      case MT_PARAM_NAME:
        if( 1 != sscanf( str + strIdx, "%s", paramBuf ) ) goto PARSE_ERROR;

        // This is true if the parameter doesn't require an axis, and causes the state machine
        // to skip the following parameter in the MESSAGE_VALUE_TYPE list
        boolean requiresAxis;
        
        // TODO: Don't copy this string, send a pointer to parseParamName
        // Then attempt to find it in the parameter list
        
        msg.fields[valIdx] = parseParamName( paramBuf, requiresAxis );
        
        if( msg.fields[valIdx] == NOT_A_PARAMETER)
          goto PARSE_ERROR;
          
        // If we got a parameter that did not require an axis specification,
        // skip an input
        if ( !requiresAxis ) {
          valIdx ++;
        }
        
        break;
    }
    
    // Advance to the next whitespace separator
    while( !isspace(str[strIdx] ) ) strIdx++;
      
    // Then advance to the next value
    valIdx++;

  }

  return true;

 PARSE_ERROR: 
  sendERROR( "message arguments did not parse" );
  msg.type = NOT_A_MESSAGE;
  return false;
}


//pre: cmd has a null terminated string ending in newline
//post: msg contains the new command
//return: 0 if a valid message was read, non-zero on error
boolean CommandInterpreter::processCommand( const char* command, Message& msg ) {
  int commandIdx = 0;
  commandIdx += parseCmdType( command, msg );

  if( msg.type == NOT_A_MESSAGE ) {
    return false;
  }

  return parseMessageValues( command + commandIdx, msg );
}


void CommandInterpreter::checkSerialInput() {
  static Message staticMsg;
  
  if( !Serial.available() ) return;
  
  commandBuf[commandBufIdx++] = Serial.read();
  commandBuf[commandBufIdx  ] = 0;

  if( commandBuf[commandBufIdx-1] == '\n' ) {
    if( !processCommand( commandBuf, staticMsg ) ) {
      commandBufIdx = 0;
      return;
    }
    if( staticMsg.type == M_ALIVE ) {
      sendACK( "ALIVE" );
      commandBufIdx = 0;
    }
    if( handler == NULL ) {
      sendERROR( "No way to parse messages!" );
      commandBufIdx = 0;
      return;
    }
    cmdHandler( &staticMsg );
    commandBufIdx = 0;
  }
  
  else if( commandBufIdx == CMD_BUF_LEN ) {
    commandBufIdx = 0;
    sendERROR( "message too long" );
    return;
  }
}
