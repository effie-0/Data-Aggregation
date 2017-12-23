#include "NodeMessage.h"
#include "AskMsg.h"
#include "SeqMsg.h"
#include "FinishReceive.h"

#define MAX_PCK_NUM 2000
#define MIN_PCK_NUM 1
#define GROUP_ID 18

module centerNodeC {
  uses interface Boot;
  uses interface Leds;
  uses interface Packet as Packet;
  uses interface AMSend as AMSend;
  uses interface Receive as Receive;

  // use serial port for debug
  uses interface Packet as SPacket;
	uses interface AMSend as SAMSend;
	uses interface Receive as SReceive;

  uses interface SplitControl as RadioControl;
  uses interface SplitControl as SerialControl; // debug
}

implementation {
  // status
  bool busy;
  bool Sbusy; // debug
  bool calFinished; // finish computation
  bool sndFinished; // finished whole result send and got ACK

  // Stored 2000 data
  uint32_t Data[MAX_PCK_NUM+1];

  // AskMsg to be sent immediately
  AskMsg AskQueue[MAX_PCK_NUM+1];
  uint16_t queue_head;
  uint16_t queue_tail;

  NodeMessage result;

  message_t askpkt; // Ask sensorNode for data
  message_t resultpkt; // Send result to Node 0
  message_t spkt; // serial pkt

  uint16_t recvSeq; // the max seqnum received
  uint16_t i; // iteration
  uint16_t maxQueueSeq; // the max seqnum in AskQueue + 1

  event void Boot.booted() {
    for(i = 0; i <= MAX_PCK_NUM; i++) {
      Data[i] = 0;
      AskQueue[i].groupid = GROUP_ID;
      AskQueue[i].seqnum = 0;
    }
    queue_head = 0;
    queue_tail = 0;

    result.groupid = GROUP_ID;
    result.max = 0;
    result.min = 0;
    result.sum = 0;
    result.average = 0;
    result.median = 0;

    calFinished = FALSE;
    sndFinished = FALSE;

    recvSeq = 0;
    maxQueueSeq = 0;

    call RadioControl.start();
    call SerialControl.start();
  }

  event void RadioControl.startDone(error_t err) {
    if (err != SUCCESS) {
      call RadioControl.start();
    }
  }

  event void RadioControl.stopDone(error_t err) {}

  event void SerialControl.startDone(error_t err) {
    if (err != SUCCESS) {
      call SerialControl.start();
    }
  }

  event void SerialControl.stopDone(error_t err) {}

  void sendAskMessage() {
    AskMsg* askPck;
    if (queue_head != queue_tail) {
      askPck = (AskMsg*)(call Packet.getPayload(&askpkt, sizeof(AskMsg)));
      if (askPck == NULL) {
        return;
      }
      askPck->groupid = AskQueue[queue_head].groupid;
      askPck->seqnum = AskQueue[queue_head].seqnum;
      if(call AMSend.send(AM_BROADCAST_ADDR, &askpkt, sizeof(AskMsg)) == SUCCESS) {
        busy = TRUE;
        call Leds.led1Toggle();
      }
    }
    else {
      busy = FALSE;
      call Leds.led1Off();
    }
  }

  void sendResultMessage() {
    NodeMsg* sndPck;
    if (calFinished && !sndFinished) {
      sndPck = (NodeMsg*)(call Packet.getPayload(&resultpkt, sizeof(NodeMsg)));
      if (sndPck == NULL) {
        return;
      }
      sndPck->groupid = result.groupid;
      sndPck->max = result.max;
      sndPck->min = result.min;
      sndPck->average = result.average;
      sndPck->median = result.median;
      if(call AMSend.send(AM_BROADCAST_ADDR, &resultpkt, sizeof(NodeMsg)) == SUCCESS) {
        busy = TRUE;
        call Leds.led0On();
      }
    }
    else {
      busy = FALSE;
      call Leds.led0Off();
    }

  }

  void s_sendMessage() {
    NodeMsg* sndPck;
    if (calFinished && !sndFinished) {
      sndPck = (NodeMsg*)(call Packet.getPayload(&spkt, sizeof(NodeMsg)));
      if (sndPck == NULL) {
        return;
      }
      sndPck->groupid = result.groupid;
      sndPck->max = result.max;
      sndPck->min = result.min;
      sndPck->average = result.average;
      sndPck->median = result.median;
      if(call SAMSend.send(AM_BROADCAST_ADDR, &spkt, sizeof(NodeMsg)) == SUCCESS) {
        Sbusy = TRUE;
        call Leds.led0On();
      }
    }
    else {
      Sbusy = FALSE;
      call Leds.led0Off();
    }
  }

  event void AMSend.sendDone(message_t* msg, error_t err) {
    busy = FALSE;
    if (calFinished) {
      call Leds.led0Off();
    }
    else {
      queue_head += 1;
      if ((queue_head != queue_tail) && (!busy)) {
        sendAskMessage();
      }
    }
  }

  event void SAMSend.sendDone(message_t* msg, error_t err) {
    Sbusy = FALSE;
    call Leds.led0Off();
  }

  event message_t* Receive.receive(message_t* msg, void* payload, uint8_t len) {
    SeqMsg* rcvPck;

    call Leds.led2Toggle();
    rcvPck = (SeqMsg*)payload;

    if(len == sizeof(SeqMsg)) {
      if(rcvPck->sequence_number == (recvSeq+1)) {
        recvSeq += 1;
        Data[recvSeq] = rcvPck->random_integer;
      }
      else if (rcvPck->sequence_number > (recvSeq+1)) {
        if ((recvSeq+1) > maxQueueSeq) {
          maxQueueSeq = recvSeq + 1;
        }
        for(i = maxQueueSeq; i <= rcvPck->sequence_number; i++) {
          AskQueue[queue_tail].seqnum = i;
          queue_tail += 1;
        }
        maxQueueSeq = rcvPck->sequence_number + 1;
        if(!busy) {
          sendAskMessage();
        }
      }
    }
    else if (len == sizeof(FinishReceive)) {
      
    }

    return msg;
  }

  event message_t* SReceive.receive(message_t* msg, void* payload, uint8_t len) {

  }
}
