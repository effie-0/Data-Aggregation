configuration centerNodeAppC {}
implementation {
  components MainC, LedsC;
  components centerNodeC as App;
  components ActiveMessageC;
  components SerialActiveMessageC;

  APP.Boot -> MainC.Boot;
  APP.Leds -> LedsC.Leds;

  App.Packet -> ActiveMessageC;
  App.AMSend -> ActiveMessageC.AMSend[AM_NODEMSG];
  App.Receive -> ActiveMessageC.Receive[AM_NODEMSG];

  App.SPacket -> SerialActiveMessageC;
	App.SAMSend -> SerialActiveMessageC.AMSend[AM_NODEMSG];
	App.SReceive -> SerialActiveMessageC.Receive[AM_NODEMSG];

  App.RadioControl -> ActiveMessageC;
  App.SerialControl -> SerialActiveMessageC;
}
