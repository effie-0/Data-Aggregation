
#include "./Calculate.h"

configuration RandomSenderC
{
}
implementation
{
	components MainC, LedsC;
	components ActiveMessageC;
	components new AMSenderC(0);
	components new AMReceiverC(0);
	components RandomSenderP;
	components new TimerMilliC() as Timer0;
	components RandomC;
	components new SensirionSht11C();
	
	RandomSenderP.Boot -> MainC;
	RandomSenderP.SplitControl -> ActiveMessageC;
	
	RandomSenderP.Packet -> AMSenderC;
	RandomSenderP.AMPacket -> AMSenderC;
	RandomSenderP.AMSend -> AMSenderC;
	RandomSenderP.Receive -> AMReceiverC;
	
	RandomSenderP.Leds -> LedsC;
	
	RandomSenderP.Timer0 -> Timer0;
	
	RandomSenderP.Random -> RandomC;
	RandomSenderP.SeedInit -> RandomC;
	
	RandomSenderP.Read -> SensirionSht11C.Temperature;
}
