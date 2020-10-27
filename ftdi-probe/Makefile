usb-bus.log: probe
	./run-probe.sh

probe: probe.c release/ftd2xx.h
	clang -o $@ -lpthread -I ./release probe.c release/build/libftd2xx.a 

release/ftd2xx.h:
	curl https://www.ftdichip.com/Drivers/D2XX/Linux/libftd2xx-x86_64-1.4.8.gz | tar xvzf -
