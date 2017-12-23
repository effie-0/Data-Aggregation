configuration sensorNodeAppC {}
implementation {
	components sensorNodeC as App;
	components MainC, LedsC;
	components ActiveMessageC;
	components SerialActiveMessageC;

	App.Boot -> MainC;
	App.Leds -> LedsC;
	
	App.Packet -> ActiveMessageC;
	App.AMSend -> ActiveMessageC.AMSend[AM_NODEMSG];
	App.Receive -> ActiveMessageC.Receive[AM_NODEMSG];

	App.SPacket -> SerialActiveMessageC;
	App.SAMSend -> SerialActiveMessageC.AMSend[AM_NODEMSG];

	App.RadioControl -> ActiveMessageC;
	App.SerialControl -> SerialActiveMessageC;
}