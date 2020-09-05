all: Mac128kRTC.axf MacPlusRTC.axf

Mac128kRTC.axf: MacRTC.c
	avr-gcc -o $@ -Os -mmcu=attiny85 -DNoXPRAM=1 $<

MacPlusRTC.axf: MacRTC.c
	avr-gcc -o $@ -Os -mmcu=attiny85 $<

clean:
	rm -f Mac128kRTC.axf MacPlusRTC.axf
