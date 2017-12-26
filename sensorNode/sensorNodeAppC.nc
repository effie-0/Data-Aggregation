configuration sensorNodeAppC {}
implementation {
	components sensorNodeC as App;
	components MainC, LedsC;
	components ActiveMessageC;

	App.Boot -> MainC;
	App.Leds -> LedsC;
	
	App.Packet -> ActiveMessageC;
	App.AMSend -> ActiveMessageC.AMSend[AM_SEQMSG];
	App.Receive -> ActiveMessageC.Receive[AM_SEQMSG];

	App.RadioControl -> ActiveMessageC;
}