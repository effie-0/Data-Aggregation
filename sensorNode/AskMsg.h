#ifndef ASKMSG_H
#define ASKMSG_H

typedef nx_struct AskMsg {
  nx_uint8_t groupid;
  nx_uint16_t seqnum;
} AskMsg;

enum { AM_ASKMSG = 6 };

#endif
