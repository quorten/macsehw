all: Mac128kRTC.axf MacPlusRTC.axf

Mac128kRTC.axf: MacRTC.cpp
	avr-gcc -o $@ -Os -mmcu=attiny85 -DNoXPRAM=1 $<

MacPlusRTC.axf: MacRTC.cpp
	avr-gcc -o $@ -Os -mmcu=attiny85 $<

clean:
	rm -f Mac128kRTC.axf MacPlusRTC.axf
