#ifndef SEQMSG_H
#define SEQMSG_H

typedef nx_struct SeqMsg {
	nx_uint16_t sequence_number;
	nx_uint32_t random_integer;
} SeqMsg;

enum { AM_SEQMSG = 10 };

#endif