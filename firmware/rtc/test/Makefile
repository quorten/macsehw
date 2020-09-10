SIMAVR_PATH = $(HOME)/src/simavr
SIMAVR_INCLUDE = $(SIMAVR_PATH)/simavr/sim
SIMAVR_LIB_DIR = $(SIMAVR_PATH)/simavr/obj-arm-linux-gnueabihf
CFLAGS = -I $(HOME)/src/simavr/simavr/sim

all: test-rtc

test-rtc: test-rtc.c
	gcc $(CFLAGS) -o $@ $< $(SIMAVR_LIB_DIR)/libsimavr.a -lelf -lrt

clean:
	rm -f test-rtc
