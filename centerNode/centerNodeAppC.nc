#include "./NodeMessage.h"

configuration centerNodeAppC 
{

}
implementation {
  components MainC, LedsC;
  components new AMSenderC(AM_NODEMSG);
  components new AMReceiverC(AM_NODEMSG);
  components new TimerMilliC() as dataTimer;
  components new TimerMilliC() as sendTimer;
  components centerNodeC as App;
  components ActiveMessageC;
  // components SerialActiveMessageC;
  components PrintfC;

  App.Boot -> MainC.Boot;
  App.Leds -> LedsC.Leds;
  App.sendTimer -> sendTimer;
  App.dataTimer -> dataTimer;

  App.Packet -> AMSenderC;
  App.AMSend -> AMSenderC;
  App.Receive -> AMReceiverC;

  // App.SPacket -> SerialActiveMessageC;
	// App.SAMSend -> SerialActiveMessageC.AMSend[AM_NODEMSG];
	// App.SReceive -> SerialActiveMessageC.Receive[AM_NODEMSG];

  App.RadioControl -> ActiveMessageC;
  // App.SerialControl -> SerialActiveMessageC;
}
