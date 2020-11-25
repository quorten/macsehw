TARGETS = bbu.vvp test_stdlogic.vvp test_mac128pal.vvp dram.vvp

all: $(TARGETS)

.SUFFIXES: .v .vvp

.v.vvp:
	iverilog -Wanachronisms -Wimplicit -Wportbind -Wselect-range \
	  -Winfloop -Wsensitivity-entire-vector \
	  -Wsensitivity-entire-array \
	  -o $@ $<

bbu.vvp: bbu.v common.vh
test_stdlogic.vvp: test_stdlogic.v stdlogic.v common.vh
test_mac128pal.vvp: test_mac128pal.v test_stdlogic.v stdlogic.v \
	mac128pal.v common.vh

clean:
	rm -f $(TARGETS)
