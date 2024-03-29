#include "printf.h"
#include "../centerNode/NodeMessage.h"
configuration sensorNodeAppC {}
implementation {
	components sensorNodeC as App;
	components MainC, LedsC;
	components new AMSenderC(AM_NODEMSG);
    components new AMReceiverC(AM_NODEMSG);
	components ActiveMessageC;
	components PrintfC;
    components SerialStartC;

	App.Boot -> MainC;
	App.Leds -> LedsC;
	
	App.Packet -> AMSenderC;
	App.AMSend -> AMSenderC;
    App.Receive -> AMReceiverC;

	App.RadioControl -> ActiveMessageC;
}