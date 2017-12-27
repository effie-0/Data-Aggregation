#ifndef SEQMSG_H
#define SEQMSG_H

typedef struct SeqMsg {
	uint16_t sequence_number;
	uint32_t random_integer;
} SeqMsg;

#endif