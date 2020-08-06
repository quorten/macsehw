# RTC Apple Custom Silicon

The RTC (Real-Time Clock) chip within the Macintosh SE is an Apple
custom silicon chip that implements the real-time clock and
battery-backed PRAM (Parameter RAM).  Fortunately, its simplicity has
yielded a fairly complete replacement chip design that is based around
the pin-compatible ATTiny85 chip running appropriate firmware.  See
the `firmware` directory for details.

Nevertheless, if we do get a microscopic chip scan of the original
silicon, this directory would contain corresponding design files to
replicate the original design as-is.  Since the chip design is so
simple, this might be easily doable with conventional DSLR macro
photography after the packaging is opened up.
