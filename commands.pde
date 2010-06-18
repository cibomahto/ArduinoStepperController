/*
 * Documenting our discussion [literals in all caps, variables in lowercase]:
 * Changes/clarifications?
 * All messages are terminated by '\n' NOT '\0'
 * 
 * GO axis position time
 * ACK GO axis position time
 * DONE
 * 
 * GO Tells the controller to move AXIS to POSITION taking TIME miliseconds to get there
 * ACK is sent by the controller immediately after GO recvd.  POSITION and TIME may be modified if POSITION was out of range or TIME was too short.
 * DONE is sent when the move completes
 * 
 * GETPOS AXIS
 * ACK GETPOS AXIS position
 * 
 * GETPOS requests the current position of AXIS from the controller
 * ACK GETPOS is sent by the controller in response and include the current position of that axis
 * 
 * SET param value
 * ACK SET param value
 * Sets PARAM to VALUE.  Valid PARAMs are: MAX_VELOCITY, MAX_ACCEL, MAX_POS, MIN_POS, ZERO_OFFSET
 * 
 * GET param value
 * ACK GET param value
 * Gets the current VALUE of PARAM.
 * 
 * HOME axis
 * ACK HOME axis
 * DONE
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
 
*/


#include "commands.h"

#include <stdlib.h>
#include <ctype.h>


#include <HardwareSerial.h>

enum MESSAGE_VALUE_TYPE {
  MT_INTEGER,
  MT_PARAM_NAME,
  NOT_A_VALUE,
};

struct ParameterDefinition {
  const char *name;
  PARAMETER param;
  int num_values; //some parameters may take more than one value: "SET MAX_SPEED axis speed", for eg.
};


// TODO: Fill out num_values here?
struct ParameterDefinition parameters[] = {
  { "MAX_VEL",  P_MAX_VEL       },
  { "ACCEL",    P_ACCEL         },
  { "POS",      P_POS           }, //read only
  { NULL,       NOT_A_PARAMETER },
};


struct MessageTypeDefinition {
  const char *name;
  MESSAGE_TYPE type;  
  enum MESSAGE_VALUE_TYPE *values;
};

static MESSAGE_VALUE_TYPE NO_VALUES[]     = {NOT_A_VALUE};
static MESSAGE_VALUE_TYPE GO_VALUES[]     = {MT_INTEGER, MT_INTEGER, MT_INTEGER, NOT_A_VALUE};
static MESSAGE_VALUE_TYPE GETPOS_VALUES[] = {MT_INTEGER, NOT_A_VALUE};
static MESSAGE_VALUE_TYPE SET_VALUES[]    = {MT_PARAM_NAME, MT_INTEGER, MT_INTEGER, NOT_A_VALUE};
static MESSAGE_VALUE_TYPE GET_VALUES[]    = {MT_PARAM_NAME, MT_INTEGER, NOT_A_VALUE};
static MESSAGE_VALUE_TYPE HOME_VALUES[]   = {MT_INTEGER, NOT_A_VALUE};

static MessageTypeDefinition messages[] = {
  { "GO",     M_GO         , GO_VALUES  },    // GO axis position time
  { "GETPOS", M_GETPOS     , GETPOS_VALUES }, // GETPOS axis
  { "SET",    M_SET        , SET_VALUES },    // SET param axis value
  { "GET",    M_GET        , GET_VALUES },    // GET param axis
  { "HOME",   M_HOME       , HOME_VALUES  },  // HOME axis
  { "STATE",  M_STATE      , NO_VALUES  },    // STATE
  { "ALIVE",  M_ALIVE      , NO_VALUES  },    // ALIVE
  { NULL,  NOT_A_MESSAGE, NULL },
};


CommandInterpreter::CommandInterpreter(CommandHandler handler) : 
  cmdBufIdx(0),
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


//returns the index of the character after the last charater in the message type or -1
//sets msg->type and msg->typeDefIdx
int CommandInterpreter::parseCmdType( const char *cmd, Message *msg ) {
  int i=0;
  while( messages[i].name != NULL ) {
    if( strncmp( cmd, messages[i].name, strlen(messages[i].name) ) == 0 ) {
      msg->type = messages[i].type;
      msg->typeDefIdx = i;
      return strlen(messages[i].name);
    }
    i++;
  }
 
  sendERROR( "message had unknown prefix" );
  msg->type = NOT_A_MESSAGE;
  return -1;
}


PARAMETER CommandInterpreter::parseParamName( const char *name ) {
  int i=0;
  while( parameters[i].name != NULL ) {
    if( strcmp( name, parameters[i].name ) == 0 ) {
      return parameters[i].param;
    }
    i++;
  }

  return NOT_A_PARAMETER;
}

//pre: msg->type is the type of message in cmd
//post: msg->fields is filled in or non-zero is returned
boolean CommandInterpreter::parseMessageValues( const char *str, Message *msg ) {
  int strIdx = 0;
  int valIdx = 0;
 
  MessageTypeDefinition *mt = &messages[msg->typeDefIdx];
  
  while( mt->values[valIdx] != NOT_A_VALUE ) {
    //advance past leading whitespace
    while( isspace( str[strIdx]) && str[strIdx] != 0 )  strIdx++;

    switch( mt->values[valIdx] ) {
    case MT_INTEGER:
      if( 1 != sscanf( str + strIdx, "%ld", &msg->fields[valIdx] ) )
	goto PARSE_ERROR;
      break;
    case MT_PARAM_NAME:
      if( 1 != sscanf( str + strIdx, "%s", paramBuf ) ) goto PARSE_ERROR;
      if( NOT_A_PARAMETER == (msg->fields[valIdx] = parseParamName( paramBuf )))
	goto PARSE_ERROR;
      break;
    }

    //advance to the next token
    while( !isspace(str[strIdx] ) ) strIdx++;
    valIdx++;
  }

  return true;

 PARSE_ERROR: 
  sendERROR( "message arguments did not parse" );
  msg->type = NOT_A_MESSAGE;
  return false;
}


//pre: cmd has a null terminated string ending in newline
//post: msg contains the new command
//return: 0 if a valid message was read, non-zero on error
boolean CommandInterpreter::processCommand( const char *cmd, Message *msg ) {
  int cmdIdx = 0;
  cmdIdx += parseCmdType( cmd, msg );

  if( msg->type == NOT_A_MESSAGE ) {
    return false;
  }

  return parseMessageValues( cmd + cmdIdx, msg );
}


void CommandInterpreter::checkSerialInput() {
  static Message staticMsg;
  
  if( !Serial.available() ) return;
  
  cmdBuf[cmdBufIdx++] = Serial.read();
  cmdBuf[cmdBufIdx  ] = 0;

  if( cmdBuf[cmdBufIdx-1] == '\n' ) {
    if( !processCommand( cmdBuf, &staticMsg ) ) {
      cmdBufIdx = 0;
      return;
    }
    if( staticMsg.type == M_ALIVE ) {
      sendACK( "ALIVE" );
      cmdBufIdx = 0;
    }
    if( handler == NULL ) {
      sendERROR( "No way to parse messages!" );
      cmdBufIdx = 0;
      return;
    }
    handler( &staticMsg );
    cmdBufIdx = 0;
  }
  
  else if( cmdBufIdx == CMD_BUF_LEN ) {
    cmdBufIdx = 0;
    sendERROR( "message too long" );
    return;
  }
}
