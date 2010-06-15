#ifndef _COMMANDS_H
#define _COMMANDS_H

#define CMD_BUF_LEN 64
#define MAX_MSG_FIELDS 4

enum MESSAGE_TYPE {
  M_GO,
  M_HOME,
  M_SET,
  M_GET,  
  NOT_A_MESSAGE,
};

enum PARAMETER {
  P_MAX_VEL,
  P_ACCEL,
  P_POS, //read only
  NOT_A_PARAMETER,
};

struct Message {
  enum MESSAGE_TYPE type;
  char typeDefIdx;
  long fields[MAX_MSG_FIELDS];
};

typedef void (*CommandHandler)( struct Message *msg );

int processCommand( const char *cmd, struct Message *msg );
void checkSerialInput();
void setCommandHandler( CommandHandler handler );

#endif
