#ifndef _COMMANDS_H
#define _COMMANDS_H

#include "WProgram.h"

#define CMD_BUF_LEN 64
#define MAX_MSG_FIELDS 4

enum MESSAGE_TYPE {
  M_GO,
  M_SET,
  M_GET,
  M_HOME,
  M_STATE,
  M_ALIVE,
  NOT_A_MESSAGE,
};

enum PARAMETER {
  P_VERSION,
  P_INDEX,
  P_MAX_VEL,
  P_ACCEL,
  P_POS, //read only
  NOT_A_PARAMETER,
};



class CommandInterpreter {
 public:
  struct Message {
    MESSAGE_TYPE type;            //< Message type (GO, SET, etc)
    char typeDefIdx;              //< Index into the 
    long fields[MAX_MSG_FIELDS];
  };

  typedef void (&CommandHandler)( Message *msg );
 
  CommandInterpreter(CommandHandler handler);
  
  void begin( unsigned int baudrate );
 
  void checkSerialInput();
  
  void sendACK( const char* message );
  void sendERROR( const char* message );

 private:
  enum MESSAGE_VALUE_TYPE {
    MT_INTEGER,
    MT_PARAM_NAME,
    NOT_A_VALUE,
  };
  
  struct MessageTypeDefinition {
    const char *name;
    MESSAGE_TYPE type;  
    enum MESSAGE_VALUE_TYPE *values;
  };
  
  struct ParameterDefinition {
    const char *name;
    PARAMETER param;
    boolean requiresAxis; // true if this parameter applies to a single axis
  };

  static MESSAGE_VALUE_TYPE NO_VALUES[];
  static MESSAGE_VALUE_TYPE GO_VALUES[];
  static MESSAGE_VALUE_TYPE SET_VALUES[];
  static MESSAGE_VALUE_TYPE GET_VALUES[];
  static MESSAGE_VALUE_TYPE HOME_VALUES[];
 
  static MessageTypeDefinition messageTypes[];
  static ParameterDefinition parameterTypes[];
 
  boolean processCommand( const char *cmd, Message *msg );
  
  void sendReply( const char *str );
  
  int parseCmdType( const char *cmd, Message *msg );
  
  PARAMETER parseParamName( const char *name, boolean& requiresAxis );
  
  boolean parseMessageValues( const char *str, Message *msg );
    
  char commandBuf[CMD_BUF_LEN+1];
  char paramBuf[CMD_BUF_LEN+1];
  char commandBufIdx;
  
  CommandHandler cmdHandler;
};

#endif

