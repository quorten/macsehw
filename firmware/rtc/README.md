# RTC

This directory contains a fully functional firmware for implementing a
drop-in replacement for the RTC on ATTiny85 microcontroller.
Unfortunately, ATTiny85 cannot be a true drop-in replacement, but you
can get pretty close.  The main caveat is time drift due to counting
seconds entirely from the internal oscillator, the crytsal oscillator
unfortunately cannot be used (efficiently/effectively) by the
ATTiny85.

The AVR core clock is run from an internal oscillator to generate 8
MHz.  The required fuse bytes setting is included in the generated ELF
object file in the `.fuse` section, in the order (low, high,
extended).  See the source code of MacRTC.c for more information on
electrical specifications and the like.

Reference source, Visited 2020-08-05:

* https://www.reddit.com/r/VintageApple/comments/91e5cf/couldnt_find_a_replacement_for_the_rtcpram_chip/e2xqq60/
* https://pastebin.com/baPZ4nN4

## Device Programming

Please note: For the ATTiny85 form factor, the external RESET pin must
be disabled since it is used for the 1-second interrupt output.
Therefore, after the initial programming, it will only be possible to
reprogram via high-voltage serial programming.
