#ifndef FINISHRECEIVE_H
#define FINISHRECEIVE_H

typedef struct FinishReceive
{
  uint16_t groupid;
  uint16_t finishSeqNum;
} FinishReceive;

enum { AM_FINISHRECEIVE = 10 };

#endif
