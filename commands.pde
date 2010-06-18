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
*/


#include "commands.h"

#include <stdlib.h>
#include <string.h>
#include <ctype.h>

#ifdef LINUX_DEBUG
#include <stdio.h>
#else
#include <HardwareSerial.h>
#endif


static char cmdBuf[CMD_BUF_LEN+1];
static char paramBuf[CMD_BUF_LEN+1];
static char cmdBufIdx = 0;

enum MESSAGE_VALUE_TYPE {
  MT_INTEGER,
  MT_PARAM_NAME,
  NOT_A_VALUE,
};

struct ParameterDefinition {
  const char *name;
  enum PARAMETER param;
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
  enum MESSAGE_TYPE type;  
  enum MESSAGE_VALUE_TYPE *values;
};

static enum MESSAGE_VALUE_TYPE NO_VALUES[]     = {NOT_A_VALUE};
static enum MESSAGE_VALUE_TYPE GO_VALUES[]     = {MT_INTEGER, MT_INTEGER, MT_INTEGER, NOT_A_VALUE};
static enum MESSAGE_VALUE_TYPE GETPOS_VALUES[] = {MT_INTEGER, NOT_A_VALUE};
static enum MESSAGE_VALUE_TYPE SET_VALUES[]    = {MT_PARAM_NAME, MT_INTEGER, MT_INTEGER, NOT_A_VALUE};
static enum MESSAGE_VALUE_TYPE GET_VALUES[]    = {MT_PARAM_NAME, MT_INTEGER, NOT_A_VALUE};
static enum MESSAGE_VALUE_TYPE HOME_VALUES[]   = {MT_INTEGER, NOT_A_VALUE};

static struct MessageTypeDefinition messages[] = {
  { "GO",     M_GO         , GO_VALUES  },    //GO axis position time
  { "GETPOS", M_GETPOS     , GETPOS_VALUES }, //GETPOS axis
  { "SET",    M_SET        , SET_VALUES },    //SET param axis value
  { "GET",    M_GET        , GET_VALUES },    //GET param axis
  { "HOME",   M_HOME       , HOME_VALUES  },  //HOME axis
  { "STATE",  M_STATE      , NO_VALUES  },    //STATE
  { NULL,  NOT_A_MESSAGE, NULL },
};static CommandHandler cmdHandler;


//returns non-zero if prefix is the prefix of string
static int isPrefix( const char *prefix, const char *string ) {
  return strncmp( prefix, string, strlen(prefix) ) == 0;
}


//serial abstraction in case we switch api later
static void sendReply( const char *str ) {
#ifdef LINUX_DEBUG
  printf( str );
  printf( "\n" );
#else
  Serial.println( str );
#endif
}


//returns the index of the character after the last charater in the message type or -1
//sets msg->type and msg->typeDefIdx
static int parseCmdType( const char *cmd, struct Message *msg ) {
  int i=0;
  while( messages[i].name != NULL ) {
    if( isPrefix( messages[i].name, cmd ) ) {
      msg->type = messages[i].type;
      msg->typeDefIdx = i;
      return strlen(messages[i].name);
    }
    i++;
  }
 
  sendReply( "ERROR message had unknown prefix" );
  msg->type = NOT_A_MESSAGE;
  return -1;
}


enum PARAMETER parseParamName( const char *name ) {
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
int parseMessageValues( const char *str, struct Message *msg ) {
  int strIdx = 0;
  int valIdx = 0;
 
  struct MessageTypeDefinition *mt = &messages[msg->typeDefIdx];
  
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
    while( !isspace(str[strIdx] ) )                       strIdx++;
    valIdx++;
  }

  return 0;

 PARSE_ERROR: 
  sendReply( "ERROR message arguments did not parse" );
  msg->type = NOT_A_MESSAGE;
  return -1;
}


//pre: cmd has a null terminated string ending in newline
//post: msg contains the new command
//return: 0 if a valid message was read, non-zero on error
int processCommand( const char *cmd, struct Message *msg ) {
  int cmdIdx = 0;
  cmdIdx += parseCmdType( cmd, msg );

  if( msg->type == NOT_A_MESSAGE ) {
    return -1;
  }

  return parseMessageValues( cmd + cmdIdx, msg );
}


static struct Message staticMsg; //dont want this on the stack



void checkSerialInput() {
  if( !Serial.available() ) return;
  
  cmdBuf[cmdBufIdx++] = Serial.read();
  cmdBuf[cmdBufIdx  ] = 0;

  if( cmdBuf[cmdBufIdx-1] == '\n' ) {
    if( 0 != processCommand( cmdBuf, &staticMsg ) ) {
      cmdBufIdx = 0;
      return;
    }
    if( handler == NULL ) {
      cmdBufIdx = 0;
      return;
    }
    handler( &staticMsg );
    cmdBufIdx = 0;
  }
  else if( cmdBufIdx == CMD_BUF_LEN ) {
    cmdBufIdx = 0;
    sendReply( "ERROR ran out of buffer space for message before the newline arrived" );
    return;
  }
}

void setCommandHandler( CommandHandler handler ) {
  cmdHandler = handler;
}
