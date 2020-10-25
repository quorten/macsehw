/* Synthesizable Verilog hardware description for a drop-in
   replacement of the Apple Custom Silicon Bob Bailey Unit (BBU), an
   address controller for the Macintosh SE and similar computers.
 
   Written in 2020 by Andrew Makousky
 
   Public Domain Dedication:
 
   To the extent possible under law, the author(s) have dedicated all
   copyright and related and neighboring rights to this software to
   the public domain worldwide. This software is distributed without
   any warranty.
 
   You should have received a copy of the CC0 Public Domain Dedication
   along with this software. If not, see
   <http://creativecommons.org/publicdomain/zero/1.0/>.

*/

/* Top-level module for the BBU.
 
   TODO Abbreviations legend, here since they are not noted elsewhere:
 
   RA = RAM Address
   RDQ = RAM Data Value
   PMCYC = Processor Memory Cycle
 
   PINOUT:

   RA0 79
   RA1 78
   RA2 76
   RA3 73
   RA4 71
   RA5 70
   RA6 68
   RA8 67
   RA7 66
   RA9 65 
   *CAS1L 16
   *CAS0L 15 
   RAM R/*W 14
   *RAS 20
   *CAS1H 19
   *CAS0H 18
   RDQ0 69
   RDQ1 72
   RDQ2 74
   RDQ3 75
   RDQ4 77
   RDQ5 80
   RDQ6 83
   RDQ7 2
   RDQ8 3
   RDQ9 4
   RDQ10 5
   RDQ11 6
   RDQ12 7
   RDQ13 8
   RDQ14 9
   RDQ15 10
   *EN245 12
   *DTACK 38
   R/*W 47
   *IPL1 30
   *LDS 33
   *VPA 36
   *C8M 37
   VCC 22
   VCC 64
   VCC 42
   VCC 84
   MBRAM 17
   GND 1
   GND 21
   GND 43
   GND 63
   ROW2 13
   *EXTDTK 11
   A23 23
   A22 24
   A21 25
   A20 26
   A19 27
   A17 28
   A9 29
   *PMCYC 81
   C2M 82
   *RES 59
   C16MRSF2 44
   C3.7M 40
   *ROMEN 39
   *SCCRD 46
   PWM 49
   SCSIDRQ 55
   *IWM 48
   *SCCEN 45
   *SCSI 57
   *DACK 56
   SNDRES 50
   VIA.CS1 58
   VIDPG2 53
   *EAREN 52
   *AS 41
   *BERR 34
   SND 51
   *VSYNC 61
   *IOW 54
   *HSYNC 60
   *VIAIRQ 32
   VIDOUT 62
   *IPL0 31
   *UDS 35

   Undocumented but assumed to exist:

   64KRAM ???
 
   Note that *IOW controls both *SCSI.IOW and *SCC.WR.
*/
module bbu_master_ctrl
   // Essential sequential logic RESET and clock signals
  (n_res, c16m, c8m, c3_7m, c2m,
   // RAM configuration pins
   row2, mbram, s64kram,
   // MC68000 signals
   a9, a17, a19, a20, a21, a22, a23,
   r_n_w, n_as, n_uds, n_lds, n_dtack,
   n_ipl0, n_ipl1, n_berr,
   n_vpa,
   // DRAM signals
   ra0, ra1, ra2, ra3, ra4, ra5, ra6, ra8, ra7, ra9,
   n_cas1l, n_cas0l, ram_r_n_w, n_ras, n_cas1h, n_cas0h,
   rdq0, rdq1, rdq2, rdq3, rdq4, rdq5, rdq6, rdq7,
   rdq8, rdq9, rdq10, rdq11, rdq12, rdq13, rdq14, rdq15,
   n_en245, n_pmcyc,
   // ROM and memory overlay signals
   n_romen,
   // VIA signals
   via_cs1, // TODO VERIFY: indeed active high?
   n_viairq,
   // Video signals
   vidpg2, vidout, n_hsync, n_vsync,
   // Sound and disk speed signals
   sndres, snd, pwm,
   // IWM signals
   n_iwm,
   // SCC signals
   n_sccen, n_sccrd, n_iow,
   // SCSI signals
   n_scsi, scsidrq, n_dack,
   // PDS signals
   n_extdtk, n_earen,
   );

   // TODO FIXME: Signals missing-in-action: OVERLAY, SNDPG2.  It's
   // possible that the Macintosh SE uses a magic address access to
   // obviate the need for consuming a VIA pin for OVERLAY, but I have
   // no idea what this address would be.  Has support for the second
   // sound page been dropped in the Macintosh SE?

   // Essential sequential logic RESET and clock signals
   input wire n_res; // *RESET signal
   input wire c16m;  // 15.667200 MHz master clock input
   output reg c8m;   // 7.8336 MHz clock output
   output reg c3_7m; // 3.672 MHz clock output
   output reg c2m;   // 1.9584 MHz clock output

   // RAM configuration pins
   input wire row2;    // 1/2 rows of RAM SIMMs jumper
   input wire mbram;   // 256K/1MB RAM SIMMs jumper
   input wire s64kram; // DOUBLY UNDOCUMENTED 64K RAM SIMMs jumper

   // MC68000 signals
   input wire a9, a17, a19, a20, a21, a22, a23;
   input wire r_n_w, n_as, n_uds, n_lds;
   output reg n_dtack, n_ipl0, n_ipl1, n_berr;
   input wire n_vpa;

   // DRAM signals
   inout wire ra0, ra1, ra2, ra3, ra4, ra5, ra6, ra8;
   output reg ra7, ra9;
   output reg n_cas1l, n_cas0l, ram_r_n_w, n_ras, n_cas1h, n_cas0h;
   inout wire rdq0, rdq1, rdq2, rdq3, rdq4, rdq5, rdq6, rdq7,
	      rdq8, rdq9, rdq10, rdq11, rdq12, rdq13, rdq14, rdq15;
   output reg n_en245, n_pmcyc;

   // ROM and memory overlay signals
   output reg n_romen;

   // VIA signals
   output reg via_cs1;
   input wire n_viairq;

   // Video signals
   input wire vidpg2;  // VIDPG2 signal
   output reg vidout;  // VIDOUT signal
   output reg n_hsync; // *HSYNC signal
   output reg n_vsync; // *VSYNC signal

   // Sound and disk speed signals
   input wire sndres;
   output reg snd, pwm;
   // IWM signals
   output reg n_iwm;
   // SCC signals
   output reg n_sccen, n_sccrd, n_iow;
   // SCSI signals
   output reg n_scsi;
   input wire scsidrq;
   output reg n_dack;
   // PDS signals
   input wire n_extdtk;
   output reg n_earen; // ??? Purpose unknown.

   // Note tristate inout ... 'bz for high impedance.  8'bz for wide.

   ///////////////////////////////////////////////////////////
   // 15.6672 / 3.6720 = 9792/2295 = (51*2^6*3)/(51*3^2*5)
   // = (2^6)/(3*5) = 64/15

   // So, here's how we implement the frequency divider to generate
   // the 3.672 MHz clock.  Initialize to 64 - 15 = 49, and keep
   // subtracting 15 until we reach zero or less.  Then, add back 49,
   // and toggle the C3.7M output.

   // TODO FIXME: The complex frequency divider will not work
   // correctly: Since the base frequency is not high enough, there
   // will be terrible aliasing artifacts.  Divide by 4 is a bit too
   // fast, divide by 5 is a bit too slow, but that's the best we can
   // do without PLL clock frequency multiplication.
   //
   // PLL clock frequency synthesis inside the BBU is conceivable to
   // believe, however, considering that the the GLUE chip in the
   // Macintosh SE/30 doubles the 16 MHz crystal input to 32 MHz.
   // Easiest method, we want the least common multiple between these
   // two frequencies.  So, back to where we started.
   //
   // 15.6672 / 3.6720 = 16/16 * 9792/2295 = (51*2^10*3)/(51*2^4*3^2*5)
   // LCM: 51*2^10*3^2*5 = 2350080 -> 235.0080 MHz
   // 235.0080 / 15.6672 = 15
   // 235.0080 / 3.6720 = 64
   //
   // So, this is how we synthesize the perfect 3.6720 MHz clock
   // signal.  Multiply the source frequency of 15.6672 MHz by 15 via
   // a PLL to get an intermediate clock frequency of 235.0080 MHz,
   // then divide by 64 to get the target 3.6720 MHz clock signal.
   // Yes, we could really just use divide-by-four (3.9168 MHz) if
   // going a tad bit faster wasn't an issue.
   //
   // How about this, 16 / (64 * 16/15) ~= 16/68.  Multiply by 16,
   // divide by 68.  PLL = 250.6752 MHz, result = 3.6864 MHz.  I guess
   // that's a lot better.  Alternatively, PLL = 250 MHz, result =
   // 3.6765 MHz.  Even better.

   // We use shift registers or 1-bit inverters for high performance,
   // minimal cycle overhead.
   reg       c16m_div2_cntr; // C16M / 2 counter
   reg [5:0] c16m_div4_cntr; // Complex C16M -> C3_7M divider counter
   reg [7:0] c16m_div8_cntr; // C16M / 8 counter

   // Table of total supported RAM sizes, used by the RAM row refresh
   // circuitry.  Note that although hardware only has 23 address
   // lines, and only 21 address lines are ever used for RAM, we
   // define these registers as 24 address lines solely for Verilog
   // source code readability.
   wire [23:0] ramsz;
   reg  [23:0] ramsz_128k;
   reg  [23:0] ramsz_256k;
   reg  [23:0] ramsz_512k;
   reg  [23:0] ramsz_1m;
   reg  [23:0] ramsz_2m;
   reg  [23:0] ramsz_2_5m;
   reg  [23:0] ramsz_4m;

   // C16M pixel clock (0.064 us per pixel).
   // 512 horizontal draw pixels, 192 horizontal blanking pixels.
   // 342 scan lines, 28 scan lines vertical blanking.
   // 60.15 Hz vertical scan rate.
   // (512 + 192) * (342 + 28) = 260480 pixel clock ticks per frame.

   // Total screen buffer size = 10944 words.  High-order bit of each
   // 16-bit word is the leftmost pixel, low-order bit is the
   // rightmost pixel.  Words in ascending order move from left to
   // right in the scan line, first scan line is topmost and then
   // moves downward.

   // The main and alternate screen buffer memory addresses are
   // calculated by subtracting a constant from the installed RAM
   // size.  Deltas: main -0x5900, alt. -0xd900.
   // Computed values for reference:
   // 128K: main 0x1a700 alt. 0x12700.
   // 256K: main 0x3a700, alt 0x32700.
   // 512K: main 0x7a700, alt. 0x72700.
   // 1MB: main 0xfa700, alt 0xf2700.
   // 2MB: main 0x1fa700, alt 0x1f2700.
   // 2.5MB: main 0x27a700, alt 0x272700.
   // 4MB: main 0x3fa700, alt 0x3f2700.

   // Please note: If we don't list the configuration in the table,
   // it's not supported by the BBU.  The BBU is a gate array, not a
   // microcontroller!

   // *HSYNC and *VSYNC counters are negative during blanking.
   reg [15:0] vidout_sreg;    // VIDOUT shift register
   reg [4:0]  vidout_cntr;    // VIDOUT remaining counter
   reg [9:0]  vid_hsync_cntr; // *HSYNC counter
   reg [8:0]  vid_vsync_cntr; // *VSYNC counter

   wire [23:0] vid_main_addr; // Address of main video buffer
   wire [23:0] vid_alt_addr;  // address of alternate video buffer

   // Table of video memory base addresses.
   // TODO FIXME: These should all be hard-wired constant registers.
   reg [23:0] vid_main_addr_128k; reg [23:0] vid_alt_addr_128k;
   reg [23:0] vid_main_addr_256k; reg [23:0] vid_alt_addr_256k;
   reg [23:0] vid_main_addr_512k; reg [23:0] vid_alt_addr_512k;
   reg [23:0] vid_main_addr_1m; reg [23:0] vid_alt_addr_1m;
   reg [23:0] vid_main_addr_2m; reg [23:0] vid_alt_addr_2m;
   reg [23:0] vid_main_addr_2_5m; reg [23:0] vid_alt_addr_2_5m;
   reg [23:0] vid_main_addr_4m; reg [23:0] vid_alt_addr_4m;

   // Sound and disk speed buffers are scanned 370 words per video
   // frame, and the size of both buffers together is 370 words.  Or,
   // 260480 pixel clock ticks / 370 = 704 pixel clock ticks per word.
   // In a single scan line, (512 + 192) / 704 = 704 / 704 = exactly 1
   // word is read.  The sound byte is the most significant byte, the
   // disk speed byte is the least significant byte.  Both the sound
   // sample and disk speed represent a PCM amplitude value, this is
   // used to generate a PDM waveform that can be processed by a
   // low-pass filter to generate the analog signal.

   // Well, at least in concept... Inside Macintosh claims that only a
   // single pulse is generated, so this is not quite your typical PDM
   // audio circuit.  Nevertheless, the sample rate is 22.2555 kHz, so
   // it's not too bad overall for generating lo-fi audio.  But, good
   // point to ponder, this is an area of improvement where a
   // different algorithm can generate better audio quality.

   // The main and alternate sound and disk speed buffer addresses are
   // calculated by subtracting a constant from the installed RAM
   // size.  Deltas: main -0x0300, alt. -0x5f00.
   // Computed values for reference:
   // 128K: main 0x1fd00 alt. 0x1a100.
   // 256K: main 0x3fd00, alt. 0x3a100.
   // 512K: main 0x7fd00, alt. 0x7a100.
   // 1MB: main 0xffd00, alt. 0xfa100.
   // 2MB: main 0x1ffd00, alt. 0x1fa100.
   // 2.5MB: main 0x27fd00, alt. 0x27a100.
   // 4MB: main 0x3ffd00, alt. 0x3fa100.

   // Please note: If we don't list the configuration in the table,
   // it's not supported by the BBU.  The BBU is a gate array, not a
   // microcontroller!
   reg [15:0] snddsk_reg; // PCM sound sample and disk speed register

   wire [23:0] snddsk_main_addr; // Address of main sound/disk buffer
   wire [23:0] snddsk_alt_addr;  // address of alternate sound/disk buffer

   // Table of sound and disk speed memory base addresses.
   // TODO FIXME: These should all be hard-wired constant registers.
   reg [23:0] snddsk_main_addr_128k; reg [23:0] snddsk_alt_addr_128k;
   reg [23:0] snddsk_main_addr_256k; reg [23:0] snddsk_alt_addr_256k;
   reg [23:0] snddsk_main_addr_512k; reg [23:0] snddsk_alt_addr_512k;
   reg [23:0] snddsk_main_addr_1m; reg [23:0] snddsk_alt_addr_1m;
   reg [23:0] snddsk_main_addr_2m; reg [23:0] snddsk_alt_addr_2m;
   reg [23:0] snddsk_main_addr_2_5m; reg [23:0] snddsk_alt_addr_2_5m;
   reg [23:0] snddsk_main_addr_4m; reg [23:0] snddsk_alt_addr_4m;

   // We must be careful that the sound circuitry does not attempt to
   // access RAM at the same time as the video circuitry.  Because the
   // phases are coherent, we can simply align the sound and disk
   // speed RAM fetch to be at a constant offset relative to the video
   // RAM fetch.

   // PLEASE NOTE: We must carefully time our RAM accesses since they
   // have delays and we don't want the screen bits shift register
   // buffer to run empty before we have the next word available from
   // RAM.  Our ideal is that the next word is available from RAM just
   // as we are shifting out the last pixel, so that we can use a
   // non-blocking assign and the new first pixel will be available
   // right at the start of the next pixel clock cycle.  Otherwise,
   // less ideal but easier to program would be to use two 16-bit
   // buffers as a FIFO.

   // SCC access notes: Even byte accesses are a read, odd byte
   // accesses are a write.  Namely: `*LDS` == 0 == write, `*UDS` == 0
   // == read.  Remember, it's big endian.  What about the separate
   // address regions?  Well, I say just ignore those, it's there for
   // a convenient convention, but it's not the officially documented
   // hardware protocol.

   // VIA support: Simply handle chip select, and issue an MC68000
   // interrupt priority zero if we receive an interrupt signal from
   // the VIA.

   // SCSI support: Handle chip select, and handle DMA.

   // NOTE: For all peripherals, we must set `*DTACK` from the BBU
   // upon successful access condition and time durations because it
   // is not set by the device itself.

   //////////////////////////////////////////////////
   // Pure combinatorial logic is defined first.

   // TODO FIXME: We need a way to detect the 2.5MB RAM configuration
   // and set the memory addresses accordingly.  The BBU could do its
   // own memory-test in this configuration to set a bit indicating
   // that there is 2.5MB of RAM installed rather than 4MB.
   assign ramsz
      = (s64kram) ? // 64K RAM SIMMs
          (~row2) ? // 1 row of RAM SIMMs
             ramsz_128k
          : // 2 rows of RAM SIMMs
             ramsz_256k
       : (~mbram) ? // 256K RAM SIMMs
          (~row2) ? // 1 row of RAM SIMMs
             ramsz_512k
          : // 2 rows of RAM SIMMs
             ramsz_1m
       : // 1MB RAM SIMMs
          (~row2) ? // 1 row of RAM SIMMs
             ramsz_2m
          : // 2 rows of RAM SIMMs
             ramsz_4m
   ;

   assign vid_main_addr
      = (s64kram) ? // 64K RAM SIMMs
          (~row2) ? // 1 row of RAM SIMMs
             vid_main_addr_128k
          : // 2 rows of RAM SIMMs
             vid_main_addr_256k
       : (~mbram) ? // 256K RAM SIMMs
          (~row2) ? // 1 row of RAM SIMMs
             vid_main_addr_512k
          : // 2 rows of RAM SIMMs
             vid_main_addr_1m
       : // 1MB RAM SIMMs
          (~row2) ? // 1 row of RAM SIMMs
             vid_main_addr_2m
          : // 2 rows of RAM SIMMs
             vid_main_addr_4m
   ;

   assign vid_alt_addr
      = (s64kram) ? // 64K RAM SIMMs
          (~row2) ? // 1 row of RAM SIMMs
             vid_alt_addr_128k
          : // 2 rows of RAM SIMMs
             vid_alt_addr_256k
       : (~mbram) ? // 256K RAM SIMMs
          (~row2) ? // 1 row of RAM SIMMs
             vid_alt_addr_512k
          : // 2 rows of RAM SIMMs
             vid_alt_addr_1m
       : // 1MB RAM SIMMs
          (~row2) ? // 1 row of RAM SIMMs
             vid_alt_addr_2m
          : // 2 rows of RAM SIMMs
             vid_alt_addr_4m
   ;

   assign snddsk_main_addr
      = (s64kram) ? // 64K RAM SIMMs
          (~row2) ? // 1 row of RAM SIMMs
             snddsk_main_addr_128k
          : // 2 rows of RAM SIMMs
             snddsk_main_addr_256k
       : (~mbram) ? // 256K RAM SIMMs
          (~row2) ? // 1 row of RAM SIMMs
             snddsk_main_addr_512k
          : // 2 rows of RAM SIMMs
             snddsk_main_addr_1m
       : // 1MB RAM SIMMs
          (~row2) ? // 1 row of RAM SIMMs
             snddsk_main_addr_2m
          : // 2 rows of RAM SIMMs
             snddsk_main_addr_4m
   ;

   assign snddsk_alt_addr
      = (s64kram) ? // 64K RAM SIMMs
          (~row2) ? // 1 row of RAM SIMMs
             snddsk_alt_addr_128k
          : // 2 rows of RAM SIMMs
             snddsk_alt_addr_256k
       : (~mbram) ? // 256K RAM SIMMs
          (~row2) ? // 1 row of RAM SIMMs
             snddsk_alt_addr_512k
          : // 2 rows of RAM SIMMs
             snddsk_alt_addr_1m
       : // 1MB RAM SIMMs
          (~row2) ? // 1 row of RAM SIMMs
             snddsk_alt_addr_2m
          : // 2 rows of RAM SIMMs
             snddsk_alt_addr_4m
   ;

   // The remainder of definitions are for sequential logic.
   always @(negedge n_res) begin
      // TODO FIXME: Initialize all hard-wired constant registers on
      // RESET.  This should not be necessary.  We could simply define
      // constants and assign those instead, assuming the compiler
      // understands the intent.
      ramsz_128k <=  'h20000;
      ramsz_256k <=  'h40000;
      ramsz_512k <=  'h80000;
      ramsz_1m   <= 'h100000;
      ramsz_2m   <= 'h200000;
      ramsz_2_5m <= 'h280000;
      ramsz_4m   <= 'h400000;

      vid_main_addr_128k <= 'h1a700; vid_alt_addr_128k <= 'h12700;
      vid_main_addr_256k <= 'h3a700; vid_alt_addr_256k <= 'h32700;
      vid_main_addr_512k <= 'h7a700; vid_alt_addr_512k <= 'h72700;
      vid_main_addr_1m <= 'hfa700; vid_alt_addr_1m <= 'hf2700;
      vid_main_addr_2m <= 'h1fa700; vid_alt_addr_2m <= 'h1f2700;
      vid_main_addr_2_5m <= 'h27a700; vid_alt_addr_2_5m <= 'h272700;
      vid_main_addr_4m <= 'h3fa700; vid_alt_addr_4m <= 'h3f2700;

      snddsk_main_addr_128k <= 'h1fd00; snddsk_alt_addr_128k <= 'h1a100;
      snddsk_main_addr_256k <= 'h3fd00; snddsk_alt_addr_256k <= 'h3a100;
      snddsk_main_addr_512k <= 'h7fd00; snddsk_alt_addr_512k <= 'h7a100;
      snddsk_main_addr_1m <= 'hffd00; snddsk_alt_addr_1m <= 'hfa100;
      snddsk_main_addr_2m <= 'h1ffd00; snddsk_alt_addr_2m <= 'h1fa100;
      snddsk_main_addr_2_5m <= 'h27fd00; snddsk_alt_addr_2_5m <= 'h27a100;
      snddsk_main_addr_4m <= 'h3ffd00; snddsk_alt_addr_4m <= 'h3fa100;

      // Initialize all output registers on RESET.
      c8m <= 0;
      c3_7m <= 0;
      c2m <= 0;

      n_dtack <= 1; n_ipl0 <= 1; n_ipl1 <= 1; n_berr <= 1;

      ra7 <= 0; ra9 <= 0;
      n_cas1l <= 1; n_cas0l <= 1;
      ram_r_n_w <= 0; n_ras <= 1;
      n_cas1h <= 1; n_cas0h <= 1;
      n_en245 <= 1;
      n_pmcyc <= 1;

      vidout <= 0; n_hsync <= 1; n_vsync <= 1;

      snd <= 0; pwm <= 0;
      n_iwm <= 1; n_sccen <= 1; n_sccrd <= 1; n_iow <= 1;
      n_scsi <= 1; n_dack <= 1;
      n_earen <= 1;

      // Initialize all internal registers on RESET.
      c16m_div2_cntr <= 0;
      c16m_div4_cntr <= 1;
      c16m_div8_cntr <= 1;
      vidout_sreg <= 0;
      vidout_cntr <= 0;
      vid_hsync_cntr <= 0;
      vid_vsync_cntr <= 0;
      snddsk_reg <= 0;
   end

   always @(posedge c16m) begin
      if (n_res) begin
	 // All high speed sequential logic goes here.

	 // Generate the frequency-divided clock signals.
	 if (c16m_div2_cntr == 1) c8m <= ~c8m;
	 c16m_div2_cntr <= ~c16m_div2_cntr;
	 if (c16m_div4_cntr[3] == 1) begin
	    c3_7m <= ~c3_7m;
	    c16m_div4_cntr <= 1;
	 end
	 else
	   c16m_div4_cntr <= { c16m_div4_cntr[4:0], c16m_div4_cntr[5] };
	 if (c16m_div8_cntr[7] == 1) c2m <= ~c2m;
	 c16m_div8_cntr <= { c16m_div8_cntr[6:0], c16m_div8_cntr[7] };
      end
   end

   always @(posedge c8m) begin
      if (n_res) begin
	 // All CPU speed sequential logic goes here.
      end
   end

   always @(posedge c3_7m) begin
      if (n_res) begin
	 // All peripheral speed sequential logic goes here.
      end
   end

   always @(posedge c2m) begin
      if (n_res) begin
	 // Only DRAM operations go here.
      end
   end

   always @(negedge c2m) begin
      if (n_res) begin
	 // Only DRAM operations go here.
      end
   end
endmodule

/*

Any time we need to request DRAM access, we need to implement a
finite-state machine as follows.

For CPU memory accesses:

1. The *AS signal is asserted.  This signals to us that we must
   process DRAM on behalf of the CPU, provided that the upper
   address bits are within the range of DRAM.  We signal our
   internal state accordingly.

2. Just before the proper cycle time we schedule PMCYC to be
   enabled.

3. We assist in setting the row access strobe from what is not
   set from the address multiplexers.  We set write-enable if
   required, depending on what the R/*W input is.

4. We assist in setting the column access strobe likewise.

4. Once the right DRAM cycle time has transpired, we enable the
   EN245 bus switcher to the DRAM and we acknowledge DRAM is
   ready to access via *DTACK.  We finally terminate once *AS is
   no longer asserted.

How do we handle 8-bit writes?  Easy, we can use the separate
column access strobes to simply never access the columns we don't
want to mutate.

1. Enqueue a DRAM access request and set our state to waiting for
   DRAM.

2. The next clock cycle finds out that a DRAM request is
   enqueued, so the DRAM logic goes through its DRAM access
   nexus, which again is a finite-state machine,.

   1. Check if we must yield to processor memory accesses, to
      prevent the BBU from starving the processor of memory
      cycles.  If so, let the processor go first, and continue
      with our use.

   2. Set the initial write-enable flag, and send the row access strobe.

   3. Send the column access strobe.

   4. After DRAM's cycle time, signal that the request has been
      completed.

3. Our code operating on its sequential cycle clock will poll the
   request status and see that the request has been completed.
   Then it will read the DRAM output into its own register and we
   will signal to execute the DRAM completion actions.

DRAM refresh?  See if we can do this during horizontal trace I
guess.

Important notes, DRAM initialization, you must do at least 8 cycles of
RAS refresh or CAS before RAS refresh before the DRAM is ready to use.

Macintosh Plus and newer DRAM speed is rated at a maximum access time
of 150 ns.  So, the 2 MHz clock is quite appropriate for row and
column access strobes.  Finally, a note on timing.  The important
thing is to make sure there is sufficient delay after asserting RAS
and CAS.  You can just have the delay times uniform and the DRAM
readout is immediately accessible after.  Oh, and write-enable?
Typically that is asserted before asserting CAS, but after asserting
RAS.  However, as I see it, asserting earlier does no harm.

Write down all my questions thus far about the BBU:

* Where the boot-time OVERLAY controlled?  I see no input signal
  to the BBU, but I'd assume the BBU must be responsible for the
  boot-time address overlays.

* Is SNDPG2 support truly eliminated from the Macintosh SE?

* How does the BBU refresh the DRAM?  Is this once at the end of
  drawing a video frame?  Unlike the Apple II, video frame
  drawing doesn't automatically refresh the DRAM because it
  doesn't access all rows of DRAM.
				     
  Is column access strobe required for DRAM refresh, or does using
  only row access strobe work just fine?  Another way of asking, do we
  use CAS before RAS refresh?  I'd say we don't make the assumption
  for greater flexibility on installed memory options.

* What are the timing requirements for DRAM access?  When does
  write-enable need to be set to function properly?

* What is the default configuration of the data bus when the CPU
  is not requesting access?  I'm assuming it is switched to
  high-impedance, i.e. all of ROM, RAM, and peripherals are
  disabled and not accessing the bus.

* Is the BBU designed to use CBR refresh on the DRAM, or does it use
  RAS refresh?
/*
 Okay, I think I'm sold on how to implement the RAM accessor circuit.

  1. Set an internal register to signal the request, and the origin of
     the request (CPU or BBU).  We actually have two sets or registers
     so both requests can be issued at the same time, and they will be
     emptied in priority order, BBU first.  This works fine since the
     BBU does not tie up DRAM during all horizontal screen cycles,
     only 50% of them.  Alternatively, instead of setting an internal
     register, we can use a wire and condition network to signal the
     condition.
 
     I say, wwhen we have questions like this, where we could design
     "pipelining" or not, write your code so that we have blocks to
     set and check the condition, and the decision whether to set and
     read from a register can be programmed in easily.

  2. On the C16M clock, check that this register is set.  If it is,
     set another register to schedule the next set of actions we will
     execute.

  3. On the falling edge of the C2M clock, as sampled by the C16M
     clock, issue the row address.  For processor memory cycles, this
     means enabling *PMCYC (drop to zero) and setting the bits
     directly controlled by the BBU.  RAM address lines not set by the
     BBU are switched to high-impedance.  For BBU memory cycles, all
     RAM address lines are set by the BBU, and *PMCYC is not used.
     Set a register to schedule the next action.

  4. On the very next C16M clock cycle, assert *RAS (drop to zero).
     We wait one C16M cycle so that we ensure the edge trigger results
     in reading a valid address.  In the case of writes, assert
     write-enable and the RAM data to write.  For processor writes,
     this means asserting *EN245 (drop to zero).  For BBU writes, this
     means setting the RAM data lines.  Set a register to schedule the
     next action.

  5. On the rising edge of the C2M clock, as sampled by the C16M
     clock, issue the column address.  Same deal as for the row
     address except that *PMCYC is already set ahead of time.  Set a
     register to schedule the next action.

  6. On the very next C16M clock cycle, assert *CAS (drop to zero).
     Set a register to schedule the next action.

  7. After 4 C16M clock cycles, trigger the RAM access completion
     conditions.  De-assert *PMCYC, *RAS, *CAS, write-enable, *EN245,
     RAM address lines, and RAM data lines (if applicable).  But do
     not de-assert *RAS, *CAS, and *EN245 for processor read memory
     cycles.  Assert *DTACK (drop to zero) for processor memory
     cycles.  Capture the RAM data read in an internal register for
     BBU memory cycles.  In the case of DRAM refreshes, increment the
     refresh row address.  In the case of BBU memory cycles, we can
     immediately check if there are queued memory access requests and
     execute the starting actions, or clear the registers to signal
     completion.  In the case of processor read memory cycles, we set
     a register to wait for the event completion signal, namely the
     de-assertion of *AS.

     NOTE: Another idea.  High-speed and low-speed circuit
     communication may sound tricky, but this is our saving grace.
     Our register latch updates are always assumed to be precise
     enough to occur on a 16 MHz clock, it's just that the
     intermediate computation actions leading up to that may take
     longer.  So, we can have both low-speed and high-speed circuits
     access the same register, so long as they use combinatorial logic
     gates to only ever allow one access at any given time.

      For the sake of high-speed circuits, technically we'll set
     a register to indicate an increment request and then do the
     actual increment on a lower-speed clock.  Then... because of the
     clock differences, we must use two different register sets to
     avoid write conflicts when we want to clear the register.
     Message passing between high-speed and low-speed clock circuits.

  8. For processor read memory cycles, once *AS is deasserted (raised
     to one), de-assert *RAS, *CAS, and *EN245.  Immediately check if
     there are queued memory access requests and execute the starting
     actions, or clear the registers to signal completion.

  In practice, we will use a single shift register for the finite
  state machine states, shift register for performance since it is
  faster than adder and compare circuits.

*/
