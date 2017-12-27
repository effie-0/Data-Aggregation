COMPONENT = centerNodeAppC
BUILD_EXTRA_DEPS += centerNodeC.class
CLEAN_EXTRA = *.class NodeMsg.java
CFLAGS += -I$(TOSDIR)/lib/net \
                   -I$(TOSDIR)/lib/net/le \
                   -I$(TOSDIR)/lib/net/ctp \
                   -I$(TOSDIR)/lib/printf
centerNodeC.class: $(wildcard *.java) NodeMsg.java
	javac -target 1.8 -source 1.8 *.java
NodeMsg.java:
	mig java -target=null $(CFLAGS) -java-classname=NodeMsg NodeMessage.h NodeMsg -o $(@)
include $(MAKERULES)
