#ifndef _COMMANDS_H
#define _COMMANDS_H

#include "WProgram.h"

#define CMD_BUF_LEN 64
#define MAX_MSG_FIELDS 4

enum MESSAGE_TYPE {
  M_GO,
  M_GETPOS,
  M_SET,
  M_GET,
  M_HOME,
  M_STATE,
  M_ALIVE,
  NOT_A_MESSAGE,
};

enum PARAMETER {
  P_MAX_VEL,
  P_ACCEL,
  P_POS, //read only
  NOT_A_PARAMETER,
};



class CommandInterpreter {
 public:
  struct Message {
    MESSAGE_TYPE type;
    char typeDefIdx;
    long fields[MAX_MSG_FIELDS];
  };

  typedef void (&CommandHandler)( Message *msg );
 
  CommandInterpreter(CommandHandler handler);
  
  void begin( unsigned int baudrate );
 
  void checkSerialInput();
  
  void sendACK( const char* message );
  void sendERROR( const char* message );

 private:
  boolean processCommand( const char *cmd, Message *msg );
  
  void sendReply( const char *str );
  
  int parseCmdType( const char *cmd, Message *msg );
  
  PARAMETER parseParamName( const char *name );
  
  boolean parseMessageValues( const char *str, Message *msg );
    
  char cmdBuf[CMD_BUF_LEN+1];
  char paramBuf[CMD_BUF_LEN+1];
  char cmdBufIdx;
  
  CommandHandler cmdHandler;
};

#endif

