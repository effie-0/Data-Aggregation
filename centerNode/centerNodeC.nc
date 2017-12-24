#include "NodeMessage.h"
#include "AskMsg.h"
#include "ACKMSg.h"
#include "SeqMsg.h"
#include "FinishReceive.h"

#define MAX_PCK_NUM 2000
#define MIN_PCK_NUM 1
#define GROUP_ID 18
#define ROOT_NODE 0
#define TIMEOUT_PERIOD 5000

module centerNodeC {
  uses interface Boot;
  uses interface Leds;
  uses interface Timer<TMilli> as sendTimer;

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
  bool collectFinished; // All data collected

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

    calFinished = FALSE;
    sndFinished = FALSE;
    collectFinished = FALSE;

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

  void Calculate() {
    uint16_t mi;

    mi = (MIN_PCK_NUM + MAX_PCK_NUM) / 2;
    QuickSort(MIN_PCK_NUM, MAX_PCK_NUM);
    result.max = Data[MAX_PCK_NUM];
    result.min = Data[MIN_PCK_NUM];
    result.sum = 0;
    for(i = MIN_PCK_NUM; i < MAX_PCK_NUM; i++) {
      result.sum += Data[i];
    }
    result.average = result.sum / (MAX_PCK_NUM - MIN_PCK_NUM + 1);
    result.median = result[mi];

    calFinished = TRUE;
    call sendResultMessage();
    call sendTimer.startPeriodic(TIMEOUT_PERIOD);
  }

  void QuickSort(uint16_t lo, uint16_t hi) {
    uint16_t mi;

    if (lo < hi) {
      mi = Partition(lo, hi);
      QuickSort(lo, mi-1);
      QuickSort(mi+1, hi);
    }
  }

  uint16_t Partition(uint16_t lo, uint16_t hi) {
    uint32_t x;
    uint32_t temp;
    uint16_t j;

    x =  = Data[hi];
    i = lo - 1;
    for(j = lo; j < hi; j++) {
      if (Data[j] <= x) {
        i += 1;
        if (i != j) {
          temp = Data[i];
          Data[i] = Data[j];
          Data[j] = temp;
        }
      }
    }
    i += 1;
    Data[hi] = Data[i];
    Data[i] = x;
    return i;
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

    if (len == sizeof(SeqMsg)) {
      if (rcvPck->sequence_number == (recvSeq+1)) {
        recvSeq += 1;
        Data[recvSeq] = rcvPck->random_integer;
        if (recvSeq == MAX_PCK_NUM) {
          collectFinished = TRUE;
          Calculate();
        }
      }
      else if (rcvPck->sequence_number > (recvSeq+1)) {
        for(i = (recvSeq+1); i <= rcvPck->sequence_number; i++) {
          AskQueue[queue_tail].seqnum = i;
          queue_tail += 1;
        }
        if (!busy) {
          sendAskMessage();
        }
      }
    }
    else if (len == sizeof(FinishReceive)) {
      if (recvSeq != MAX_PCK_NUM) {
        for(i = (recvSeq+1); i <= MAX_PCK_NUM; i++) {
          AskQueue[queue_tail].seqnum = i;
          queue_tail += 1;
        }
        if (!busy) {
          sendAskMessage();
        }
      }
    }
    else if (len == sizeof(ACKMsg)) {
      sndFinished = TRUE;
      call sendTimer.stop();
      call Leds.led0On();
      call Leds.led1On();
      call Leds.led2On();
    }

    return msg;
  }

  event message_t* SReceive.receive(message_t* msg, void* payload, uint8_t len) {

  }

  event void sendTimer.fired() {
    call sendTimer.stop();
    call sendResultMessage();
    call sendTimer.startPeriodic(TIMEOUT_PERIOD);
  }
}
