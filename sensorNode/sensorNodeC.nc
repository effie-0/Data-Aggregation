#include "SeqMsg.h"
#include "../centerNode/AskMsg.h"
// #include "FinishReceive.h"

#define MAX_INTEGER_NUM 2005
#define MAX_ASK_MSG_NUM 500
#define ROOT_NODE 1
#define GROUP_ID 18

module sensorNodeC {
	uses interface Boot;
	uses interface Leds;
	
	uses interface Packet as Packet;
    uses interface AMSend as AMSend;
	uses interface Receive as Receive;
	uses interface SplitControl as RadioControl;
}

implementation {
	// status
	bool busy;
	// bool sendingFinishMsg;
	uint16_t base;

	uint16_t PICK_PERIOD;

	message_t pkt;
	uint32_t randomIntegers[MAX_INTEGER_NUM];
	uint16_t count;
	uint16_t queue_head;
	uint16_t queue_tail;
	SeqMsg seqqueue[200];

	// iteration variable
	uint16_t i;

	message_t pkt;

	event void Boot.booted() {
		queue_head = 0;
		queue_tail = 0;
		for (i = 0;i <= MAX_INTEGER_NUM;i++) {
			randomIntegers[i] = -1;
		}
		busy = FALSE;
		// sendingFinishMsg = FALSE;

		call RadioControl.start();

		// debug
		count = 0;
	}

    event void RadioControl.startDone(error_t err)
	{
		if(err != SUCCESS)
			call RadioControl.start();
	}
	
	event void RadioControl.stopDone(error_t err) { }

	void sendMessage() {
		SeqMsg* sndPck;
		call Leds.led0Toggle();
		sndPck = (SeqMsg*)(call Packet.getPayload(&pkt, sizeof(SeqMsg)));
		sndPck->sequence_number = seqqueue[queue_head].sequence_number;
		sndPck->random_integer = seqqueue[queue_head].random_integer;
			
		if (call AMSend.send(AM_BROADCAST_ADDR, &pkt, sizeof(SeqMsg)) == SUCCESS) {
			// debug
			busy = TRUE;
		}
	}

	event void AMSend.sendDone(message_t* m, error_t err) {
		if (queue_tail == queue_head) {
			busy = FALSE;
			return;
		}
		else if (queue_head != queue_tail) {
			queue_head = (queue_head + 1) % 200;
			busy = TRUE;
			sendMessage();
		}
	}

	event message_t* Receive.receive(message_t* msg, void* payload, uint8_t len) {
		// NodeMsg* rcvPck;
		uint16_t dis;
		SeqMsg *seqMsgRcvPck;
		AskMsg *askMsgRcvPck;

		call Leds.led2Toggle();
		// FinishReceive *sndPck;

        count += 1;
		if(len == sizeof(SeqMsg)) {
			seqMsgRcvPck = (SeqMsg*)payload;
			if (seqMsgRcvPck->sequence_number > 0 && seqMsgRcvPck->sequence_number <= MAX_INTEGER_NUM) {
				randomIntegers[seqMsgRcvPck->sequence_number] = seqMsgRcvPck->random_integer;
			}
	    } else if(len == sizeof(AskMsg)) {
	    	call Leds.led1Toggle();
			askMsgRcvPck = (AskMsg*)payload;
			// debug
				for (i = 0;i < SEQ_SIZE;i++) {
					if ((askMsgRcvPck->seqnum[i] > 0) && (askMsgRcvPck->seqnum[i] <= MAX_INTEGER_NUM) && (randomIntegers[askMsgRcvPck->seqnum[i]] != -1)) {
						seqqueue[queue_tail].sequence_number = askMsgRcvPck->seqnum[i];
						seqqueue[queue_tail].random_integer = randomIntegers[askMsgRcvPck->seqnum[i]];
						queue_tail = (queue_tail + 1) % 200;
						if (!busy) {
							busy = TRUE;
							sendMessage();
						}

					}
					
				}
			
		}
		return msg;
	}
}
