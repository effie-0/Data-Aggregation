#include "SeqMsg.h"
#include "AskMsg.h"
#include "FinishReceive.h"

#define MAX_INTEGER_NUM 2000
#define MAX_ASK_MSG_NUM 500
#define ROOT_NODE 0
#define GROUP_ID 18

module sensorNodeC {
	uses interface Boot;
	uses interface Leds;
	
	uses interface Packet as Packet;
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
	uint32_t AskedSequenceNumbersQueue[MAX_ASK_MSG_NUM];
	uint16_t queue_head;
	uint16_t queue_tail;
	uint16_t sentFinishReceive;

	// iteration variable
	uint16_t i;

	message_t pkt;

	event void Boot.booted() {
		for (i = 0;i < MAX_INTEGER_NUM;i++) {
			MsgQueue[i].sequence_number = -1;
			MsgQueue[i].random_integer = -1;
		}
		for (i = 0;i < MAX_ASK_MSG_NUM;i++) {
			AskedSequenceNumbersQueue[i] = -1;
		}
		queue_head = 0;
		queue_tail = 0;
		sentFinishReceive = 0;

		call RadioControl.start();
	}

	event void RadioControl.startDone(error_t err) {
		if (err != SUCCESS) {
			call RadioControl.start();
		}
	}
	
	event void RadioControl.stopDone(error_t err) {}

	void sendMessage() {
		SeqMsg* sndPck;
		uint16_t askedSequenceNumber;
		if (queue_head == queue_tail) {
			return;
		}
		sndPck = (SeqMsg*)(call Packet.getPayload(&pkt, sizeof(SeqMsg)));
		askedSequenceNumber = AskedSequenceNumbersQueue[queue_head];
		sndPck->sequence_number = MsgQueue[askedSequenceNumber - 1].sequence_number;
		sndPck->random_integer = MsgQueue[askedSequenceNumber - 1].random_integer;
			
		if (call AMSend.send(AM_BROADCAST_ADDR, &pkt, sizeof(SeqMsg)) == SUCCESS) {
			busy = TRUE;
			call Leds.led1Toggle();
		}
	}

	event void AMSend.sendDone(message_t* m, error_t err) {
		busy = FALSE;
		if (sentFinishReceive == 0) {
			sentFinishReceive = 1;
			return;
		}
		queue_head = (queue_head + 1) % MAX_ASK_MSG_NUM;
		if (queue_head != queue_tail) {
			sendMessage();
		}
	}

	event message_t* Receive.receive(message_t* msg, void* payload, uint8_t len) {
		// NodeMsg* rcvPck;
		uint16_t dis;
		SeqMsg *seqMsgRcvPck;
		AskMsg *askMsgRcvPck;
		FinishReceive *sndPck;

		call Leds.led0Toggle();
		// rcvPck = (NodeMsg*)payload;
		if(len == sizeof(SeqMsg)) {
			seqMsgRcvPck = (SeqMsg*)payload;
			if (seqMsgRcvPck->sequence_number > 0 && seqMsgRcvPck->sequence_number <= MAX_INTEGER_NUM) {
				MsgQueue[seqMsgRcvPck->sequence_number - 1].sequence_number = seqMsgRcvPck->sequence_number;
			    MsgQueue[seqMsgRcvPck->sequence_number - 1].random_integer = seqMsgRcvPck->random_integer;
			    if(seqMsgRcvPck->sequence_number == MAX_INTEGER_NUM) {
				    while(busy) {}
		            sndPck = (FinishReceive*)(call Packet.getPayload(&pkt, sizeof(FinishReceive)));
			        sndPck->groupid = GROUP_ID * 3 + TOS_NODE_ID;
			        sndPck->finishSeqNum = MAX_INTEGER_NUM;
				    if (call AMSend.send(AM_BROADCAST_ADDR, &pkt, sizeof(FinishReceive)) == SUCCESS) {
			            busy = TRUE;
			            call Leds.led2Toggle();
		            }
			    }
			}
		} else if(len == sizeof(AskMsg)) {
			askMsgRcvPck = (AskMsg*)payload;
			if (askMsgRcvPck->seqnum > 0 && askMsgRcvPck->seqnum <= MAX_INTEGER_NUM && MsgQueue[askMsgRcvPck->seqnum - 1].sequence_number != -1) {
				AskedSequenceNumbersQueue[queue_tail] = askMsgRcvPck->seqnum;
			    queue_tail = (queue_tail + 1) % MAX_ASK_MSG_NUM;
			    if (!busy) {
				    sendMessage();
			    }
			}
		}
		return msg;
	}
}
