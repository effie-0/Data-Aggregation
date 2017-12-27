#include "printf.h"
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
	uses interface Receive as Receive;
	uses interface SplitControl as RadioControl;
}

implementation {
	// status
	bool busy;
	uint16_t base;

	uint16_t PICK_PERIOD;

	message_t pkt;
	uint32_t randomIntegers[MAX_INTEGER_NUM];
	uint16_t AskedSequenceNumbersQueue[MAX_ASK_MSG_NUM];
	uint16_t queue_head;
	uint16_t queue_tail;
	uint16_t sentFinishReceive;
	uint16_t count;

	// iteration variable
	uint16_t i;

	message_t pkt;

	event void Boot.booted() {
		for (i = 0;i < MAX_INTEGER_NUM;i++) {
			randomIntegers[i] = -1;
		}
		for (i = 0;i < MAX_ASK_MSG_NUM;i++) {
			AskedSequenceNumbersQueue[i] = -1;
		}
		queue_head = 0;
		queue_tail = 0;
		sentFinishReceive = 0;
		busy = FALSE;

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
		uint16_t askedSequenceNumber;
		if (queue_head == queue_tail) {
			return;
		}
		sndPck = (SeqMsg*)(call Packet.getPayload(&pkt, sizeof(SeqMsg)));
		askedSequenceNumber = AskedSequenceNumbersQueue[queue_head];
		sndPck->sequence_number = askedSequenceNumber;
		sndPck->random_integer = randomIntegers[askedSequenceNumber - 1];
			
		if (call AMSend.send(AM_BROADCAST_ADDR, &pkt, sizeof(SeqMsg)) == SUCCESS) {
			// debug
			// printf("Sent SeqMsg. seq: %u, int: %ld\n", sndPck->sequence_number, sndPck->random_integer);
			busy = TRUE;
		}
	}

	event void AMSend.sendDone(message_t* m, error_t err) {
		busy = FALSE;
		if (sentFinishReceive == 0) {
			// debug
			// printf("Sent finish receive\n");
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

		if (count % 100 == 0) {
            call Leds.led0Toggle();
         }
         count += 1;
		// rcvPck = (NodeMsg*)payload;
		if(len == sizeof(SeqMsg)) {
			seqMsgRcvPck = (SeqMsg*)payload;
			// debug
			// printf("Received SeqMsg. Sequence number: %u, random integer: %ld\n", seqMsgRcvPck->sequence_number, seqMsgRcvPck->random_integer);
			if (seqMsgRcvPck->sequence_number > 0 && seqMsgRcvPck->sequence_number <= MAX_INTEGER_NUM && randomIntegers[seqMsgRcvPck->sequence_number - 1] != seqMsgRcvPck->random_integer) {
				// debug
				// printf("Received valid SeqMsg. Sequence number: %u, random integer: %ld\n", seqMsgRcvPck->sequence_number, seqMsgRcvPck->random_integer);
			    randomIntegers[seqMsgRcvPck->sequence_number - 1] = seqMsgRcvPck->random_integer;
			    if(seqMsgRcvPck->sequence_number == MAX_INTEGER_NUM && !busy) {
		            sndPck = (FinishReceive*)(call Packet.getPayload(&pkt, sizeof(FinishReceive)));
			        sndPck->groupid = GROUP_ID * 3 + TOS_NODE_ID;
			        sndPck->finishSeqNum = MAX_INTEGER_NUM;
			        sentFinishReceive = 0;
				    if (call AMSend.send(AM_BROADCAST_ADDR, &pkt, sizeof(FinishReceive)) == SUCCESS) {
			            busy = TRUE;
			            call Leds.led1On();
		            }
			    }
			}
		} else if(len == sizeof(AskMsg)) {
			askMsgRcvPck = (AskMsg*)payload;
			// debug
			// printf("Received AskMsg. Sequence number: %u\n", askMsgRcvPck->seqnum);
			// printf("randomIntegers[askMsgRcvPck->seqnum - 1]: %u\n", randomIntegers[askMsgRcvPck->seqnum - 1]);
			if (askMsgRcvPck->seqnum > 0 && askMsgRcvPck->seqnum <= MAX_INTEGER_NUM && randomIntegers[askMsgRcvPck->seqnum - 1] != -1) {
				// debug
				// printf("Asked seq %u is recorded.\n", askMsgRcvPck->seqnum);
				call Leds.led2Toggle();
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
