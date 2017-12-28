#include "NodeMessage.h"
#include "AskMsg.h"
#include "ACKMsg.h"
#include "../sensorNode/SeqMsg.h"

#define MAX_PCK_NUM 2000
#define MIN_PCK_NUM 1
#define MY_QUEUE_SIZE 20
#define GROUP_ID 18
#define ROOT_NODE 0
#define TIMEOUT_PERIOD 5000
#define ASK_PERIOD 500

module centerNodeC {
  uses interface Boot;
  uses interface Leds;
  uses interface Timer<TMilli> as sendTimer;
  uses interface Timer<TMilli> as dataTimer;

  uses interface Packet as Packet;
  uses interface AMSend as AMSend;
  uses interface Receive as Receive;

  // use serial port for debug
  uses interface Packet as SPacket;
	uses interface AMSend as SAMSend;

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
  bool askStart;
  bool bit1check; // for sorting
  bool bit2check;

  // Stored 2000 data
  uint32_t Data[MAX_PCK_NUM+2];

  // AskMsg to be sent immediately
  AskMsg AskQueue[MY_QUEUE_SIZE];
  uint16_t queue_head;
  uint16_t queue_tail;

  NodeMsg result;

  message_t askpkt; // Ask sensorNode for data
  message_t resultpkt; // Send result to Node 0
  message_t spkt; // serial pkt
  message_t debugpkt;
  message_t seqdebugpkt;

  uint16_t recvSeq; // the max seqnum received
  uint16_t i; // iteration
  uint16_t count;

  uint16_t mleft;// for sorting
  uint16_t mright;
  uint16_t total;
  uint32_t bit1;
  uint32_t bit2;
  uint32_t x;

  uint16_t validIndex;

  event void Boot.booted() {
    uint16_t j;

    for(i = 0; i <= MAX_PCK_NUM; i++) {
      Data[i] = -1;
    }
    for(i = 0; i < MY_QUEUE_SIZE; i++) {
      AskQueue[i].groupid = GROUP_ID;
      for(j = 0; j < SEQ_SIZE; j++) {
        AskQueue[i].seqnum[j] = -1;
      }
    }
    queue_head = 0;
    queue_tail = 0;

    result.groupid = GROUP_ID;
    result.max = 0;
    result.min = -1;
    result.sum = 0;
    result.average = 0;
    result.median = 0;

    recvSeq = 0;

    calFinished = FALSE;
    sndFinished = FALSE;
    collectFinished = FALSE;
    askStart = FALSE;

    bit1check = FALSE;
    bit2check = FALSE;
    total = 2000;

    call RadioControl.start();
    call SerialControl.start();

    count = 0;
    validIndex = 0;
  }

  event void RadioControl.startDone(error_t err) {
    if (err != SUCCESS) {
      call RadioControl.start();
    }
  }

  event void RadioControl.stopDone(error_t err) {
  }

  event void SerialControl.startDone(error_t err) {
    if (err != SUCCESS) {
       call SerialControl.start();
     }
  }

  event void SerialControl.stopDone(error_t err) {}

  void sendAskMessage() {
    AskMsg* askPck;
    uint16_t j;

    if (queue_head != queue_tail) {
      askPck = (AskMsg*)(call Packet.getPayload(&askpkt, sizeof(AskMsg)));
      if (askPck == NULL) {
        return;
      }

      askPck->groupid = AskQueue[queue_head].groupid;
      for(j = 0; j < SEQ_SIZE; j++) {
        askPck->seqnum[j] = AskQueue[queue_head].seqnum[j];
      }


      if(call AMSend.send(AM_BROADCAST_ADDR, &askpkt, sizeof(AskMsg)) == SUCCESS) {
        busy = TRUE;
      }
    }
    else {
      busy = FALSE;
      queue_head = 0;
      queue_tail = 0;
      //call Leds.led1Off();
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
      sndPck->sum = result.sum;
      sndPck->average = result.average;
      sndPck->median = result.median;
      if(call AMSend.send(AM_BROADCAST_ADDR, &resultpkt, sizeof(NodeMsg)) == SUCCESS) {
        busy = TRUE;
      }
    }
    else {
      busy = FALSE;
    }

  }

  uint16_t Partition(uint16_t lo, uint16_t hi) {
    uint32_t num;
    uint32_t temp;
    uint16_t j, k;

    num = Data[hi];
    k = lo - 1;
    for(j = lo; j < hi; j++) {
      if (Data[j] <= num) {
        k += 1;
        if (k != j) {
          temp = Data[k];
          Data[k] = Data[j];
          Data[j] = temp;
        }
      }
    }
    k += 1;
    Data[hi] = Data[k];
    Data[k] = num;
    return k;
  }

  void QuickSort(uint16_t lo, uint16_t hi) {
    uint16_t mi;

    if (lo < hi) {
      mi = Partition(lo, hi);
      QuickSort(lo, mi-1);
      QuickSort(mi+1, hi);
    }
  }

  void bubbleSort(uint16_t lo, uint16_t hi) {
    uint16_t ai, aj;
    uint16_t flag;
    for (ai = lo; ai < hi; ai++) {
      for (aj = ai + 1; aj <= hi; aj++) {
        if (Data[ai] > Data[aj]) {
          ai = ai + aj;
          aj = ai - aj;
          ai = ai - aj;
        }
      }
    }
  }

  uint32_t newQuickSort(uint16_t lo, uint16_t hi) {
    mleft = lo;
    mright = hi;
    while(1) {
      lo = mleft;
      hi = mright;
      x = Data[mright];
      while(mleft < mright) {
        while(mleft < mright && Data[mleft] <= x) {
          mleft++;
        }
        if (mleft < mright) {
          Data[mright] = Data[mleft];
        }
        while(mleft < mright && Data[mright] >= x) {
          mright--;
        }
        if (mleft < mright) {
          Data[mleft] = Data[mright];
        }
      }
      Data[mright] = x;
      if (mright == (total / 2)) {
        bit1check = TRUE;
        bit1 = Data[mright];
      }
      else if (mright == (total / 2 + 1)) {
        bit2check = TRUE;
        bit2 = Data[mright];
      }

      if (bit1check && bit2check) {
        return (bit1 + bit2) / 2;
      }
      else {
        if (mleft <= (total / 2)) {
          mleft++;
          mright = hi;
        }
        else if (mright >= (total / 2 + 1)) {
          mright--;
          mleft = lo;
        }
      }
    }
  }

  void Calculate() {
    uint16_t j;
    uint16_t mi;
    uint32_t median;
    NodeMsg* debugPCK;
    debugPCK = (NodeMsg*)(call SPacket.getPayload(&debugpkt, sizeof(NodeMsg)));

    call Leds.led2On();
    mi = (MIN_PCK_NUM + MAX_PCK_NUM) / 2;
    median = newQuickSort(MIN_PCK_NUM, MAX_PCK_NUM);
    result.sum = 0;
    for(j = MIN_PCK_NUM; j <= MAX_PCK_NUM; j++) {
      if (Data[j] > result.max) {
        result.max = Data[j];
      }
      if (result.min == -1) {
        result.min = Data[j];
      }
      else if (result.min > Data[j]) {
        result.min = Data[j];
      }
      result.sum += Data[j];
    }
    result.average = result.sum / (MAX_PCK_NUM - MIN_PCK_NUM + 1);
    result.median = median;

    calFinished = TRUE;
    sendResultMessage();

    debugPCK->groupid = GROUP_ID;
    debugPCK->max = result.max;
    debugPCK->min = result.min;
    debugPCK->sum = result.sum;
    debugPCK->average = result.average;
    debugPCK->median = result.median;
    call SAMSend.send(AM_BROADCAST_ADDR, &debugpkt, sizeof(NodeMsg));
    call sendTimer.startPeriodic(TIMEOUT_PERIOD);
    call Leds.led2Off();
  }

  void AskForData() {
    uint16_t j;
    // debug
    call Leds.led1Toggle();
    if (queue_head != queue_tail) {
      // haven't finished asking
      return;
    }

    queue_head = 0;
    queue_tail = 0;
    j = 0;
    for(i = MIN_PCK_NUM; i <= MAX_PCK_NUM; i++) {
      if (Data[i] == -1 && queue_tail != MY_QUEUE_SIZE) {
        AskQueue[queue_tail].seqnum[j] = i;
        j += 1;
        if (j >= SEQ_SIZE) {
          queue_tail += 1;
          j = 0;
        }
      }
    }
    if (j != 0) {
      queue_tail += 1;
    }

    if (queue_head == queue_tail) {
      //printf("queue_head == queue_tail\n");
      collectFinished = TRUE;
      Calculate();
    }
    else {
      if (!busy) {
        sendAskMessage();
      }
    }
  }

  event void SAMSend.sendDone(message_t* msg, error_t err) {
    Sbusy = FALSE;
  }

  event void AMSend.sendDone(message_t* msg, error_t err) {
    uint16_t j;
    busy = FALSE;
    if (calFinished) {
    }
    else {
      for(j = 0; j < SEQ_SIZE; j++) {
        AskQueue[queue_head].seqnum[j] = -1;
      }
      queue_head += 1;
      if ((queue_head != queue_tail) && (!busy)) {
        sendAskMessage();
      }
    }
  }

  event message_t* Receive.receive(message_t* msg, void* payload, uint8_t len) {
    SeqMsg* rcvPck;
    ACKMsg* ackPck;
    count += 1;
    call Leds.led0Toggle();

    if (len == sizeof(SeqMsg)) {
      call Leds.led1Toggle();
      rcvPck = (SeqMsg*)payload;
      // debug
      if (rcvPck->random_integer == -1)
        return msg;
      
      if (Data[rcvPck->sequence_number] == -1) {
        validIndex += 1;
        Data[rcvPck->sequence_number] = rcvPck->random_integer;
        if (validIndex == 2000 && !collectFinished) {
          collectFinished = TRUE; // All data collected
          Calculate();
        }
      }
      if (validIndex > 1800 || rcvPck->sequence_number == MAX_PCK_NUM) {
        if (!askStart) {
          askStart = TRUE;
          AskForData();
          call dataTimer.startPeriodic(ASK_PERIOD);
        }
      }
    }
    else if (len == sizeof(ACKMsg)) {
      ackPck = (ACKMsg*)payload;
      if (ackPck->group_id == GROUP_ID) {
        sndFinished = TRUE;
        call sendTimer.stop();
      }
    }

    return msg;
  }

  event void sendTimer.fired() {
    call sendTimer.stop();
    sendResultMessage();
    call sendTimer.startPeriodic(TIMEOUT_PERIOD);
  }

  event void dataTimer.fired() {
    if (collectFinished) {
      call dataTimer.stop();
      return;
    }
    AskForData();
  }

}
