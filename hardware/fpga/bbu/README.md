# "BBU" Apple Custom Silicon

The "BBU", as it is called on the Macintosh SE's printed circuit board
silkscreen, is a relatively complex Apple custom silicon chip,
compared to the other custom chips on the Macintosh SE's Main Logic
Board (MLB).  Despite its intimidating look as a chip with a huge
number of pins, its purpose can be summarized as follows.

* Provide a single address bus interface to ROM, RAM, and I/O devices,
  including simple digital I/O pins.

* Scan the CRT by driving the primary digital control signals
  (`*VSYNC`, `*HSYNC`, `VIDOUT`).

There might be additional processing functions it may provide as a
convenience between the CPU and the various other hardware chips, but
chances are these processing functions are relatively simple.

Most of the I/O pins that are connected to the BBU are single-bit
digital I/O signals that are relatively easy to understand.  Reverse
engineering the Macintosh SE's firmware may be required to determine
how these pins are mapped into the CPU's address space, but once that
determination is made, providing a replica interface to most of the
connected hardware should be super-easy.

The following I/O chips are connected to the BBU:

* VIA interrupt controller

* IWM/SWIM floppy disk controller

* SCSI Controller

* Serial Communications Controller (SCC)

Other chips that are connected to the BBU are mainly interfaced via
only simple, single-pin interfaces.
