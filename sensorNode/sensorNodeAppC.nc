configuration sensorNodeAppC {}
implementation {
	components sensorNodeC as App;
	components MainC, LedsC;
	components new AMSenderC(0);
    components new AMReceiverC(10) as dataReceiver;
	components ActiveMessageC;

	App.Boot -> MainC;
	App.Leds -> LedsC;
	
	App.Packet -> AMSenderC;
	App.AMSend -> AMSenderC;
	App.dataReceive -> dataReceiver;

	App.radioControl -> ActiveMessageC;
}