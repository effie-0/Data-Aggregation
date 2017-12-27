#ifndef MSGRECORD_H
#define MSGRECORD_H

typedef nx_struct MsgRecord {
	nx_uint8_t is_received;
	nx_uint32_t random_integer;
} MsgRecord;

#endif