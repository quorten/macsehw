#! /bin/sh
avr-gcc -c -Os -mmcu=attiny85 MacRTC.cpp
avr-gcc -mmcu=attiny85 -o MacRTC.axf MacRTC.o
