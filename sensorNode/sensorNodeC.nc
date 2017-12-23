#include "SeqMsg.h"
#include "AskMsg.h"

#define MAX_INTEGER_NUM 2000
#define ROOT_NODE 0

module sensorNodeC {
	uses interface Boot;
	uses interface Leds;
	
	uses interface AMSend as AMSend;
	uses interface Receive;

	uses interface SplitControl as RadioControl;
}

implementation {
	// status
	bool busy;
	uint16_t base;

	uint16_t PICK_PERIOD;

	message_t pkt;
	SeqMsg MsgQueue[MAX_INTEGER_NUM];

	// iteration variable
	uint16_t i;

	event void Boot.booted() {
		for (i = 0;i < MAX_INTEGER_NUM;i++) {
			MsgQueue[i].sequence_number = -1;
			MsgQueue[i].random_integer = -1;
		}

		call RadioControl.start();
	}

	event void RadioControl.startDone(error_t err) {
		if (err != SUCCESS) {
			call RadioControl.start();
		}
	}
	
	event void RadioControl.stopDone(error_t err) {}

	void sendMessage(nx_uint16_t sequence_number, nx_uint32_t random_integer) {
		SeqMsg* sndPck;
			sndPck->sequence_number = sequence_number;
			sndPck->random_integer = random_integer;
			
			if (call AMSend.send(AM_BROADCAST_ADDR, &pkt, sizeof(SeqMsg)) == SUCCESS) {
				busy = TRUE;
				call Leds.led1Toggle();
			}
	}

	event message_t* Receive.receive(message_t* msg, void* payload, uint8_t len) {
		NodeMsg* rcvPck;
		uint16_t dis;

		call Leds.led2Toggle();
		rcvPck = (NodeMsg*)payload;
		if(len == sizeof(SeqMsg) && rcvPck->sequence_number > 0 && rcvPck->sequence_number <= MAX_INTEGER_NUM) {
			MsgQueue[rcvPck->sequence_number - 1].sequence_number = rcvPck->sequence_number;
			MsgQueue[rcvPck->sequence_number - 1].random_integer = rcvPck->random_integer;
		} else if(len == sizeof(AskMsg) && rcvPck->seqnum > 0 && rcvPck->seqnum <= MAX_INTEGER_NUM && MsgQueue[rcvPck->seqnum].sequence_number != -1 && !busy) {
			sendMessage(rcvPck->seqnum, MsgQueue[rcvPck->seqnum].random_integer);
		}
		return msg;
	}
}