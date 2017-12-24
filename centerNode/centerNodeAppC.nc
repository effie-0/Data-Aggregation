configuration centerNodeAppC {}
implementation {
  components MainC, LedsC;
  components new TimerMilliC() as dataTimer;
  components new TimerMilliC() as sendTimer;
  components centerNodeC as App;
  components ActiveMessageC;
  components SerialActiveMessageC;

  App.Boot -> MainC.Boot;
  App.Leds -> LedsC.Leds;
  App.sendTimer -> sendTimer;

  App.Packet -> ActiveMessageC;
  App.AMSend -> ActiveMessageC.AMSend[AM_NODEMSG];
  App.Receive -> ActiveMessageC.Receive[AM_NODEMSG];

  App.SPacket -> SerialActiveMessageC;
	App.SAMSend -> SerialActiveMessageC.AMSend[AM_NODEMSG];
	App.SReceive -> SerialActiveMessageC.Receive[AM_NODEMSG];

  App.RadioControl -> ActiveMessageC;
  App.SerialControl -> SerialActiveMessageC;
}
