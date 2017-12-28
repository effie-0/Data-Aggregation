#ifndef ASKMSG_H
#define ASKMSG_H

enum { SEQ_SIZE = 7 };

typedef nx_struct AskMsg {
  nx_uint8_t groupid;
  nx_uint16_t seqnum[SEQ_SIZE];
} AskMsg;

#endif
