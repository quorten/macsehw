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

// NOTE: These constants are defined in lower-case because they are
// meant to be treated principally as if they are hard-wired
// registers.

// Table of total supported RAM sizes, used by the RAM row refresh
// circuitry.  Note that although hardware only has 23 address
// lines, and only 21 address lines are ever used for RAM, we
// define these registers as 24 address lines solely for Verilog
// source code readability.
`define ramsz_128k  24'h20000
`define ramsz_256k  24'h40000
`define ramsz_512k  24'h80000
`define ramsz_1m   24'h100000
`define ramsz_2m   24'h200000
`define ramsz_2_5m 24'h280000
`define ramsz_4m   24'h400000

// Enumerant values and "shift register indices" for RAM size.
`define RAMSZ_EN_128K 7'b0000001
`define RAMSZ_ENI_128K 0
`define RAMSZ_EN_256K 7'b0000010
`define RAMSZ_ENI_256K 1
`define RAMSZ_EN_512K 7'b0000100
`define RAMSZ_ENI_512K 2
`define RAMSZ_EN_1M 7'b0001000
`define RAMSZ_ENI_1M 3
`define RAMSZ_EN_2M 7'b0010000
`define RAMSZ_ENI_2M 4
`define RAMSZ_EN_2_5M 7'b0100000
`define RAMSZ_ENI_2_5M 5
`define RAMSZ_EN_4M 7'b1000000
`define RAMSZ_ENI_4M 6

// The main and alternate screen buffer memory addresses are
// calculated by subtracting a constant from the installed RAM size.
// Deltas: main -0x5900, alt. -0xd900.
// Computed values for reference:
// 128K: main 0x1a700 alt. 0x12700.
// 256K: main 0x3a700, alt 0x32700.
// 512K: main 0x7a700, alt. 0x72700.
// 1MB: main 0xfa700, alt 0xf2700.
// 2MB: main 0x1fa700, alt 0x1f2700.
// 2.5MB: main 0x27a700, alt 0x272700.
// 4MB: main 0x3fa700, alt 0x3f2700.

// Please note: If we don't list the configuration in the table, it's
// not supported by the BBU.  The BBU is a gate array, not a
// microcontroller!

// Table of video memory base addresses.
`define vid_main_addr_128k 24'h1a700
`define vid_alt_addr_128k  24'h12700
`define vid_main_addr_256k 24'h3a700
`define vid_alt_addr_256k  24'h32700
`define vid_main_addr_512k 24'h7a700
`define vid_alt_addr_512k  24'h72700
`define vid_main_addr_1m 24'hfa700
`define vid_alt_addr_1m  24'hf2700
`define vid_main_addr_2m 24'h1fa700
`define vid_alt_addr_2m  24'h1f2700
`define vid_main_addr_2_5m 24'h27a700
`define vid_alt_addr_2_5m  24'h272700
`define vid_main_addr_4m 24'h3fa700
`define vid_alt_addr_4m  24'h3f2700

// The main and alternate sound and disk speed buffer addresses are
// calculated by subtracting a constant from the installed RAM size.
// Deltas: main -0x0300, alt. -0x5f00.
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

// Table of sound and disk speed memory base addresses.
`define snddsk_main_addr_128k 24'h1fd00
`define snddsk_alt_addr_128k  24'h1a100
`define snddsk_main_addr_256k 24'h3fd00
`define snddsk_alt_addr_256k  24'h3a100
`define snddsk_main_addr_512k 24'h7fd00
`define snddsk_alt_addr_512k  24'h7a100
`define snddsk_main_addr_1m 24'hffd00
`define snddsk_alt_addr_1m  24'hfa100
`define snddsk_main_addr_2m 24'h1ffd00
`define snddsk_alt_addr_2m  24'h1fa100
`define snddsk_main_addr_2_5m 24'h27fd00
`define snddsk_alt_addr_2_5m  24'h27a100
`define snddsk_main_addr_4m 24'h3ffd00
`define snddsk_alt_addr_4m  24'h3fa100

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
   via_cs1,
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
   // sound page been dropped in the Macintosh SE?  Yes, indeed it has
   // been.  Nevertheless... for the sake of possibly making
   // quasi-hardware replicas of earlier Macintosh computers easier,
   // we will preserve an implementation here anyways.  As for the
   // OVERLAY signal, we'll have to use Mini vMac's guess on how to
   // implement it.  At boot, the ROM exclusively accesses the ROM
   // overlay addresses and the remapped RAM address when setting up.
   // When it is done, it jumps into the standard ROM address access.
   // As soon as the BBU detects this memory access (any address in
   // the standard ROM address space), it switches the overlay, and it
   // cannot be switched back except by a RESET signal.

   // So yes... it turns out the BBU must actually do address bus
   // snooping.

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
   output reg n_dtack, n_ipl0, n_ipl1;
   output wire n_berr;
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

   // Boot-time memory overlay switch, 1 = enable, 0 = disable.
   reg boot_overlay;
   // In order to implement the memory overlay switch, we must snoop
   // the address bus.  These are the registers we use to store the
   // address multiplexor outputs.
   reg [7:0] row_snoop; reg [7:0] col_snoop;

   // Installed RAM size.
   wire [23:0] ramsz;

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

   // *HSYNC and *VSYNC counters are negative during blanking.
   reg [15:0] vidout_sreg;    // VIDOUT shift register
   reg [4:0]  vidout_cntr;    // VIDOUT remaining counter
   reg [9:0]  vid_hsync_cntr; // *HSYNC counter
   reg [8:0]  vid_vsync_cntr; // *VSYNC counter

   wire [23:0] vid_main_addr; // Address of main video buffer
   wire [23:0] vid_alt_addr;  // Address of alternate video buffer

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

   reg [15:0] snddsk_reg; // PCM sound sample and disk speed register

   wire [23:0] snddsk_main_addr; // Address of main sound/disk buffer
   wire [23:0] snddsk_alt_addr;  // Address of alternate sound/disk buffer

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

   //////////////////////////////////////////////////
   // Sub-modules are instantiated here.

   // The remainder of definitions are for sequential logic.
   always @(negedge n_res) begin
      // Initialize all output registers on RESET.

      n_dtack <= 1; n_ipl0 <= 1; n_ipl1 <= 1;

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
      boot_overlay <= 1;
      vidout_sreg <= 0;
      vidout_cntr <= 0;
      vid_hsync_cntr <= 0;
      vid_vsync_cntr <= 0;
      snddsk_reg <= 0;
   end

   always @(posedge c16m) begin
      if (n_res) begin
	 // All high speed sequential logic goes here.
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

PLEASE NOTE: One memory access can occur on one cycle of the 2 MHz
clock, we use the falling and rising edges to time the emission of row
access strobe and column access strobe respectively.  Since we fetch
16 bits at a time, this allows for fetching two bits per 16 MHz cycle.
Since we only need one screen bit per 16 MHz cycle, this means we only
consume 50% of the memory bus cycles during horizontal scan, the other
50% of cycles are free for CPU memory accesses.  The important thing,
access cycles are assigned constantly, and the CPU is forced to wait
until its turn.  Video access only happens on a constant index, there
is no dynamic schedule requesting.

But actually, PLEASE NOTE.  Despite the labeling of the circuits, the
Macintosh SE actually uses a 75%/25% between the CPU and the vdieo
memory access due to its performance edge.  Macintosh Plus and earlier
models used 50/50.  Well, vague hint... that doesn't really make sense
to me, though, I'll just fo with 50/50 and leave that note in place.

Plase note that audio buffers are fetched at the end of horizontal
lines.

Write down all my questions thus far about the BBU:

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
*/

// Clock divider module.  Generate the frequency-divided clock
// signals.
module clock_div (n_res, c16m, c8m, c3_7m, c2m, n_pmcyc);
   input wire n_res;
   input wire c16m;
   output reg c8m;
   output reg c3_7m;
   // c2m is now controlled by the DRAM controller state machine.
   input wire c2m;
   output reg n_pmcyc;

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

   // TODO: Optimize this to minimize the number of register bits
   // required, while still preserving ideal frequency division and
   // synchronization behavior.

   // We use shift registers or 1-bit inverters for high performance,
   // minimal cycle overhead.
   reg [5:0] c16m_div4_cntr; // Complex C16M -> C3_7M divider counter
   // reg [3:0] c16m_div8_cntr; // C16M / 8 counter
   reg [7:0] c16m_div16_cntr; // C16M / 16 counter

   always @(negedge n_res) begin
      // Initialize all output registers on RESET.
      c8m <= 0;
      c3_7m <= 0;
      // c2m <= 0;
      n_pmcyc <= 1;

      // Initialize all internal registers on RESET.
      c16m_div4_cntr <= 1;
      // c16m_div8_cntr <= 1;
      c16m_div16_cntr <= 1;
   end

   always @(posedge c16m) begin
      if (n_res) begin
	 c8m <= ~c8m;
	 if (c16m_div4_cntr[1]) begin
	    c3_7m <= ~c3_7m;
	    c16m_div4_cntr <= 1;
	 end
	 else
	   c16m_div4_cntr <= { c16m_div4_cntr[4:0], c16m_div4_cntr[5] };
	 // if (c16m_div8_cntr[3]) c2m <= ~c2m;
	 // c16m_div8_cntr <= { c16m_div8_cntr[2:0], c16m_div8_cntr[3] };
	 if (c16m_div16_cntr[7]) n_pmcyc <= ~n_pmcyc;
	 c16m_div16_cntr <= { c16m_div16_cntr[6:0], c16m_div16_cntr[7] };
      end
   end
endmodule

// RAM configuration options module.  Process the RAM configuration
// jumpers and generate the corresponding internal RAM configuration
// and address map signals.
module ram_config (row2, mbram, s64kram,
		   ramsz, ramsz_en, vid_main_addr, vid_alt_addr,
		   snddsk_main_addr, snddsk_alt_addr);
   // RAM configuration pins
   input wire row2;    // 1/2 rows of RAM SIMMs jumper
   input wire mbram;   // 256K/1MB RAM SIMMs jumper
   input wire s64kram; // DOUBLY UNDOCUMENTED 64K RAM SIMMs jumper

   // Installed RAM size.
   output wire [23:0] ramsz;

   // Symbolic enumerant for installed RAM size.  We use this in
   // "shift register" fashion to keep downstream logic gates simple.
   output wire [6:0] ramsz_en;

   // Address of main video buffer
   output wire [23:0] vid_main_addr;
   // Address of alternate video buffer
   output wire [23:0] vid_alt_addr;

   // Address of main sound/disk buffer
   output wire [23:0] snddsk_main_addr;
   // Address of alternate sound/disk buffer
   output wire [23:0] snddsk_alt_addr;

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

   assign ramsz_en
      = (s64kram) ? // 64K RAM SIMMs
          (~row2) ? // 1 row of RAM SIMMs
             RAMSZ_EN_128K
          : // 2 rows of RAM SIMMs
             RAMSZ_EN_256K
       : (~mbram) ? // 256K RAM SIMMs
          (~row2) ? // 1 row of RAM SIMMs
             RAMSZ_EN_512K
          : // 2 rows of RAM SIMMs
             RAMSZ_EN_1M
       : // 1MB RAM SIMMs
          (~row2) ? // 1 row of RAM SIMMs
             RAMSZ_EN_2M
          : // 2 rows of RAM SIMMs
             RAMSZ_EN_4M
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

endmodule

/* Check the high address bits and boot-time memory overlay to
   determine which zone an address access is within and set the RAM,
   ROM, or device enable signals accordingly.  If an address is in an
   invalid range, a bus error can optionally be signaled.  N.B.: Note
   that the *RAMEN signal is only used internally for the sake of more
   modular implementation.
 
   These are the particular address zones for Macintosh SE, according
   to MESS/MAME source code.  In particular, SCC and IWM are
   surrounded with invalid address guard zones:

   * 0x000000 - 0x3fffff: RAM/ROM (switches based on overlay)
   * 0x400000 - 0x4fffff: ROM
   * 0x580000 - 0x5fffff: 5380 NCR/Symbios SCSI peripherals chip
   * 0x600000 - 0x6fffff: RAM, boot-time overlay only
   * 0x900000 - 0x9fffff: Zilog 8530 SCC (Serial Control Chip) Read
   * 0xb00000 - 0xbfffff: Zilog 8530 SCC (Serial Control Chip) Write
   * 0xd00000 - 0xdfffff: IWM (Integrated Woz Machine; floppy)
   * 0xe80000 - 0xefffff: Rockwell 6522 VIA
   * 0xf00000 - 0xffffef: ??? (the ROM appears to be accessing here)
   * 0xfffff0 - 0xffffff: Auto Vector

*/
module decode_devaddr (n_ramen, n_romen, n_scsi, n_sccen, n_sccrd,
		       n_iwm, via_cs1, n_berr, a23_19,
		       boot_overlay, r_n_w, reg_romen, reg_ram_w);
   output wire n_ramen;
   output wire n_romen;
   output wire n_scsi;
   output wire n_sccen;
   output wire n_sccrd;
   output wire n_iwm;
   output wire via_cs1;
   output wire n_berr;
   input wire [4:0] a23_19;
   input wire boot_overlay;
   input wire r_n_w;
   // Has an address access to the regular *ROMEN zone occurred?  This
   // signal is used to disable the boot-time memory overlay.
   output wire reg_romen;
   // Have we attempted to write to the regular RAM address zone?
   output wire reg_ram_w;

   wire berr_ram;

   // If the boot-time overlay is enabled but we attempt to write to
   // the regular RAM region, then this is a *RAMEN trigger.  The
   // overlay control logic will zero the switch on the next cycle,
   // but we use combinatorial logic here to act immediately.
   assign reg_ram_w = (~r_n_w & (a23_19[4:3] == 2'b00));
   assign n_ramen = ~((boot_overlay) ? (a23_19[4:1] == 4'b0110) :
		      (a23_19[4:3] == 2'b00)) &
		    ~reg_ram_w;
   assign reg_romen = (a23_19[4:1] == 4'h4);
   // Only trigger *ROMEN for reads, not writes.
   assign n_romen = ~(reg_romen |
		      (boot_overlay & r_n_w & (a23_19[4:3] == 2'b00)));
   assign n_scsi  = ~(a23_19[4:0] == 5'b01011);
   assign n_sccen = ~((a23_19[4:1] == 4'h9) |
		      (a23_19[4:1] == 4'hb));
   assign n_sccrd = ~(a23_19[4:1] == 4'h9);
   assign n_iwm   = ~(a23_19[4:1] == 4'hd);
   assign via_cs1 =  (a23_19[4:0] == 5'b11101);
   // TODO: We don't currently implement Auto Vector, but neither does
   // MESS/MAME but its emulation still works just fine?  There could
   // be ROM patch hacks...

   // TODO: Signal a bus error for out-of-range RAM addresses.  Make
   // sure to also signal errors in the boot-time overlay when booting
   // with less than 1 MB of RAM.  This would require decoding more
   // address bits, though.
   assign berr_ram = 0;

   assign n_berr = ~(berr_ram |
		     (a23_19[4:0] == 5'b01010) |
		     (a23_19[4:1] == 4'h7) |
		     (a23_19[4:1] == 4'h8) |
		     (a23_19[4:1] == 4'ha) |
		     (a23_19[4:1] == 4'hc) |
		     (a23_19[4:0] == 5'b11100));
   // TODO: Also flag bus errors for the final address zone.
endmodule

// Boot-time memory overlay register and controlling logic.  This is
// fairly straightforward to implement once you see all the other
// logic of the BBU in place.
module overlay_logic (n_res, clk, overlay, reg_romen, reg_ram_w);
   input wire n_res;
   input wire clk;
   output reg overlay;
   input wire reg_romen;
   input wire reg_ram_w;

   always @(negedge n_res) begin
      // Initialize the overlay switch to ENABLED on RESET.
      overlay <= 1;
   end

   always @(posedge clk) begin
      if (n_res) begin
	 // Disable the overlay on the first access to the regular ROM
	 // address zone.  And, according to MESS/MAME, also disable
	 // on the first attempt to write the regular RAM zone.
	 if (reg_romen | reg_ram_w)
	   overlay <= 0;
	 else
	   ; // Nothing to be done.
      end
   end
endmodule // btm_overlay


// Column address strobe decode logic.  Determine which column access
// strobe line to assert based off of the installed RAM, high-order
// CPU address lines, and *LDS/*UDS signals.
module dramctl_cas (n_cas, n_cas0h, n_cas0l, n_cas1h, n_cas1l,
		    n_uds, n_lds, row2, mbram, s64kram,
		    a17, a19, a21);
   input wire n_cas;
   output wire n_cas0l, n_cas0h, n_cas1l, n_cas1h;
   input wire n_uds, n_lds;
   input wire row2;    // 1/2 rows of RAM SIMMs jumper
   input wire mbram;   // 256K/1MB RAM SIMMs jumper
   input wire s64kram; // DOUBLY UNDOCUMENTED 64K RAM SIMMs jumper
   input wire a17, a19, a21;

   wire row1en; // Enable row 1?  ("Second" row.)

   assign row1en = (s64kram) ? a17 : (~mbram) ? a19 : a21;
   assign n_cas0h = ~(~n_uds &
		      ((row2) ? ~row1en : 1));
   assign n_cas0l = ~(~n_lds &
		      ((row2) ? ~row1en : 1));
   assign n_cas1h = ~(~n_uds & row2 & row1en);
   assign n_cas1l = ~(~n_lds & row2 & row1en);
endmodule

// RA7/RA9 selector logic.  Determine which CPU address pins should be
// routed to these RAM address pins based off of the installed RAM.
module dramctl_ra7_9 (ra7, ra9, cas_n_ras, row2, mbram, s64kram,
		      a9, a17, a19, a20, a10);
   output wire ra7;
   output wire ra9;
   input wire cas_n_ras; // CAS/*RAS
   input wire row2;    // 1/2 rows of RAM SIMMs jumper
   input wire mbram;   // 256K/1MB RAM SIMMs jumper
   input wire s64kram; // DOUBLY UNDOCUMENTED 64K RAM SIMMs jumper
   input wire a9, a17, a19, a20;
   input wire a10; // Snooped from address bus

   assign ra7
     = (s64kram) ? // 64K RAM SIMMs
       (~cas_n_ras) ? a9 : a10
       : // 256K RAM SIMMs and 1MB RAM SIMMs
       (~cas_n_ras) ? a17 : a9
   ;
   assign ra9
     = (mbram) ? // 1MB RAM SIMMs
       (~cas_n_ras) ? a20 : a19
       : // <1MB RAM SIMMs
       0 // RA9 is not used
   ;
endmodule

// Module to decode a 21-bit address into RAM row and column address
// buffers.  Just combinatorial logic, no registers.  For ease of
// programming, least significant address bit zero is also included
// even though it is not used.
module decode_drcaddr (a, row_addr, col_addr, s64kram);
   input wire [20:0] a;
   output wire [9:0] row_addr;
   output wire [9:0] col_addr;
   input wire s64kram;

   wire ra7r, ra7c, ra9r, ra9c;

   assign ra7r
     = (s64kram) ? // 64K RAM SIMMs
       a[9]
       : // >=256K RAM SIMMs
       a[17]
   ;
   assign ra7c
     = (s64kram) ? // 64K RAM SIMMs
       a[10]
       : // >=256K RAM SIMMs
       a[9]
   ;
   assign ra9r = a[20];
   assign ra9c = a[19];
   assign row_addr = { ra9r, a[18], ra7r, a[16:11], a[1] };
   assign col_addr = { ra9c, a[10], ra7c, a[8:2] };
endmodule

// Decode A0 into MC68000 upper and lower data strobes for a single
// 8-bit byte memory access.  MC68000 is big endian, so *UDS is byte
// address zero, *LDS is byte address one.
module a0_to_ds (a0, n_uds, n_lds);
   input wire a0;
   output wire n_uds, n_lds;
   assign n_uds = a0;
   assign n_lds = ~a0;
endmodule

// Stateful advancement DRAM controller logic for CPU memory accesses.
module dramctl_cpu (n_res, clk, r_n_w, c2m,
		    ram_r_n_w, n_as, n_ras, n_cas,
		    n_en245, n_pmcyc, n_dtack,
		    ra, row_snoop, col_snoop, snoop_valid);
   input wire n_res, clk, r_n_w;
   output reg c2m;
   input wire n_as;
   output wire ram_r_n_w;
   // Row Address Strobe (*RAS), Column Address Strobe (*CAS)
   output reg n_ras, n_cas;
   // *EN245 controls the bus switches to remove CPU access to RAM
   // data output/input (RDQ) by placing those lanes in a
   // high-impedance state.
   output reg n_en245;
   // *PMCYC principally enables the row/column address multiplexors.
   // At a higher level, it is used to determine whether it is the
   // CPU's turn to access RAM or the BBU's turn to access RAM.  The
   // CPU always takes a multiple of 4 clock cycles running at 8 MHz
   // to access RAM.  This signal could possibly be just wired up to a
   // 1 MHz clock.
   input wire n_pmcyc;
   // output reg n_pmcyc;
   output reg n_dtack;

   input wire [9:0] ra; // RAM Address (RA)
   // In order to implement the memory overlay switch, we must snoop
   // the address bus.  These are the registers we use to store the
   // address multiplexor outputs.
   // N.B. RA7 and RA9 are set by us, but for simplicity of downstream
   // code, we capture them into the address snooping registers
   // regardless.
   output reg [9:0] row_snoop;
   output reg [9:0] col_snoop;
   output reg snoop_valid;

   wire n_as_full;
   // N.B. We use a shift-register style state buffer for speed and
   // simplicity.
   reg [5:0] drc_state_buf;
   wire [5:0] drc_state;

   // Internal "full" address strobe signal: only assert when both *AS
   // and *PMCYC are asserted.  Bit-wise OR by De Morgan's Theorem.
   assign n_as_full = n_as | n_pmcyc;

   // Use combinatorial logic to advance into state 4 under as quickly
   // as possible when the respective conditions are met.  We skip
   // state 2 because it is redundant by virtue of the BBU
   // implementation.
   assign drc_state = drc_state_buf ^
                      (~n_pmcyc & drc_state_buf[0] & ~n_as_full) ? 5 : 0;

   // Set RAM R/*W based off of the CPU output and simply checking
   // that we are not in state 1.
   assign ram_r_n_w = (drc_state[0]) ? 1 : r_n_w;

   always @(negedge n_res) begin
      // Initialize all output registers on RESET.
      c2m <= 0;
      n_ras <= 1;
      n_cas <= 1;
      n_en245 <= 1;
      // n_pmcyc <= 1;
      n_dtack <= 1;

      row_snoop <= 0;
      col_snoop <= 0;
      snoop_valid <= 0;

      // Initialize all internal registers on RESET.
      drc_state_buf <= 1;
   end

   always @(posedge clk) begin
      if (n_res) begin
	 // Check *AS before checking the case statements for a faster
	 // response to when *AS is released.
	 if (n_as_full) begin
	    if (~drc_state[0]) begin // State != 1
	       // Abort or finish the DRAM access when we get the
	       // release signal.
	       c2m <= 0;
	       n_ras <= 1;
	       n_cas <= 1;
	       // n_pmcyc <= 1;
	       n_en245 <= 1;
	       n_dtack <= 1;
	       drc_state_buf <= 1; // Finished.
	    end
	    else /* if (drc_state[0]) */
	      ; // Nothing to be done.
	 end
	 else /* if (~n_as_full) */ begin
	    // N.B.: Using case statements might not generate the most
	    // efficient hardware because the generated hardware might
	    // be checking to ensure all the other bits are zero,
	    // which is not needed here.  Hence a bunch of if
	    // statements.
	    // if (drc_state[0]) begin // State 1
	          // Initiate the DRAM access process in a serial
	          // mannner.  This alternative approach to
	          // combinatorial logic up-front can be faster for
	          // very high-speed code, but it is not desired for
	          // Macintosh BBU cycle timing.
	          // drc_state_buf <= 1;
	    // end

	    // N.B.: State 2 is skipped because our master immediately
	    // triggers *PMCYC at the beginning of the CPU's turn to
	    // access memory.
	    // if (drc_state[1]) begin // State 2
	    //    // Enable the row address multiplexors.
	    //    n_pmcyc <= 0;
	    //    // Trigger *EN245 as early as possible.
	    //    n_en245 <= 0;
	    //    // Invalidate the snoop status.
	    //    snoop_valid <= 0;
	    //    drc_state_buf <= drc_state << 1;
	    // end

	    if (drc_state[2]) begin // State 4
	       // Trigger *RAS.
	       n_ras <= 0;
	       // Trigger *EN245 as early as possible.
	       n_en245 <= 0;
	       // Snoop the row address.
	       row_snoop <= ra;
	       // Invalidate the snoop status.
	       snoop_valid <= 0;
	       drc_state_buf <= drc_state << 1;
	    end
	    if (drc_state[3]) begin // State 8
	       // Enable the column address multiplexors.
	       c2m <= 1;
	       drc_state_buf <= drc_state << 1;
	    end

	    // N.B.: If we wanted even faster DRAM controller response
	    // to CPU requests, then we could trigger *CAS and *DTACK
	    // in state 4 and use use combinatorial logic gate delays
	    // to ensure that the column access strobe does not reach
	    // the DRAM before the column address has stabilized.  The
	    // CPU only checks *DTACK on select clock cycles, which is
	    // why it is okay for us to set it a little bit too early.

	    // However, please note tha column address snooping must
	    // still happen in state 16.

	    if (drc_state[4]) begin // State 16
	       // Trigger *CAS and signal the DRAM data is ready.
	       n_cas <= 0;
	       n_dtack <= 0;
	       // Snoop the column address.
	       col_snoop <= ra;
	       // Signal that we successfully snooped a full address
	       // from the bus.
	       snoop_valid <= 1;
	       drc_state_buf <= drc_state << 1;
	    end
	    // State 32: No state advancement until *AS is no longer
	    // triggered, then we execute the finish sequence.
	    // default: ; // Other states should never happen.
	 end
      end
      else
	; // Nothing to be done during RESET.
   end
endmodule

// Stateful advancement DRAM controller logic for BBU memory accesses.
// TODO: Try to see a single internal state register can be shared
// across these two stateful DRAM controller modules, because only one
// will ever be used at a time and run to completion.
module dramctl_bbu (n_res, clk, r_n_w,
		    ram_r_n_w, n_as, n_ras, n_cas,
		    n_pmcyc, n_dtack,
		    ra, row_addr, col_addr, bbu_dtack);
   input wire n_res, clk, r_n_w;
   input wire n_as;
   output wire ram_r_n_w;
   // Row Address Strobe (*RAS), Column Address Strobe (*CAS)
   output reg n_ras, n_cas;
   // *PMCYC principally enables the row/column address multiplexors.
   // At a higher level, it is used to determine whether it is the
   // CPU's turn to access RAM or the BBU's turn to access RAM.  The
   // CPU always takes a multiple of 4 clock cycles running at 8 MHz
   // to access RAM.  This signal could possibly be just wired up to a
   // 1 MHz clock.
   input wire n_pmcyc;
   output wire n_dtack;

   output reg [9:0] ra; // RAM Address (RA)
   input wire [9:0] row_addr;
   input wire [9:0] col_addr;
   output wire bbu_dtack;

   wire n_as_full;
   // N.B. We use a shift-register style state buffer for speed and
   // simplicity.
   reg [6:0] drc_state_buf;
   wire [6:0] drc_state;

   // Internal "full" address strobe signal: only assert when *AS is
   // asserted and *PMCYC is deasserted.  Bit-wise OR by De Morgan's
   // Theorem.
   assign n_as_full = n_as | ~n_pmcyc;

   // Use combinatorial logic to advance into state 2 under as quickly
   // as possible when the respective conditions are met.
   assign drc_state = drc_state_buf ^
                      (n_pmcyc & drc_state_buf[0] & ~n_as_full) ? 3 : 0;

   // Set RAM R/*W based off of the BBU command and simply checking
   // that we are not in state 1.
   assign ram_r_n_w = (drc_state[0]) ? 1 : r_n_w;

   // BBU internal DRAM accesses always hold the CPU *DTACK line high.
   assign n_dtack = 1;

   // The BBU internal DTACK is simply implemented by checking that we
   // are in state 64.
   assign bbu_dtack = drc_state[6];

   always @(negedge n_res) begin
      // Initialize all output registers on RESET.
      ra <= 10'bz; // Set to high-impedance to disable output.
      n_ras <= 1;
      n_cas <= 1;

      // Initialize all internal registers on RESET.
      drc_state_buf <= 1;
   end

   always @(posedge clk) begin
      if (n_res) begin
	 // Check *AS before checking the case statements for a faster
	 // response to when *AS is released.
	 if (n_as_full) begin
	    if (~drc_state[0]) begin // State != 1
	       // Abort or finish the DRAM access when we get the
	       // release signal.
	       ra <= 10'bz; // Set to high-impedance to disable output.
	       n_ras <= 1;
	       n_cas <= 1;
	       drc_state_buf <= 1; // Finished.
	    end
	    else /* if (drc_state[0]) */
	      ; // Nothing to be done.
	 end
	 else /* if (~n_as_full) */ begin
	    // N.B.: Using case statements might not generate the most
	    // efficient hardware because the generated hardware might
	    // be checking to ensure all the other bits are zero,
	    // which is not needed here.  Hence a bunch of if
	    // statements.
	    // if (drc_state[0]) begin // State 1
	          // Initiate the DRAM access process in a serial
	          // mannner.  This alternative approach to
	          // combinatorial logic up-front can be faster for
	          // very high-speed code, but it is not desired for
	          // Macintosh BBU cycle timing.
	          // drc_state_buf <= 1;
	    // end

	    if (drc_state[1]) begin // State 2
	       // Enable the row address multiplexors.
	       ra <= row_addr;
	       drc_state_buf <= drc_state << 1;
	    end
	    if (drc_state[2]) begin // State 4
	       // Trigger *RAS.
	       n_ras <= 0;
	       drc_state_buf <= drc_state << 1;
	    end
	    if (drc_state[3]) begin // State 8
	       // Enable the column address multiplexors.
	       ra <= col_addr;
	       drc_state_buf <= drc_state << 1;
	    end
	    if (drc_state[4]) begin // State 16
	       // Trigger *CAS.
	       n_cas <= 0;
	       drc_state_buf <= drc_state << 1;
	    end
	    if (drc_state[5]) begin // State 32
	       // Signal the DRAM data is ready (via combinatorial
	       // logic).  We need to make sure we wait the nominal
	       // number of cycles for the DRAM to be ready, unlike
	       // the case for CPU accesses where it will wait on its
	       // own due to the nature of its clock cycle alignment.
	       drc_state_buf <= drc_state << 1;
	    end
	    // State 64: No state advancement until *AS is no longer
	    // triggered, then we execute the finish sequence.
	    // default: ; // Other states should never happen.
	 end
      end
      else
	; // Nothing to be done during RESET.
   end
endmodule

// TODO: Module to fetch an address from DRAM and store it in the
// destination BBU internal register.  This will be just a coding
// exercise because of Verilog silliness.  Actually, might as well
// make two modules since that is all that is needed to start: one for
// video, one for DRAM.
module fetch_vid_addr (n_res, clk, n_as, a, vidreg, s64kram);
   input wire n_res;
   input wire clk;
   input wire n_as;
   input wire [20:0] a;
   output reg [15:0] vidreg;
   input wire s64kram;

   wire [9:0] row_addr;
   wire [9:0] col_addr;

   decode_drcaddr u0 (a, row_addr, col_addr, s64kram);
   // TODO: Schedule the memory access request and now wait until we
   // are signaled ready.  How?  Well, I recommend using... a
   // dedicated module for the scheduling logic.  Well, first of all,
   // we're running timers and clocks for all matters of RAM accesses.
   // We know those are guaranteed not to conflict since everything is
   // carefully required to take turns on known intervals.  So,
   // remember that, no queuing logic needed.  The DRAM access request
   // will be able to be fulfilled immediately.  We just need to check
   // the counters to know which register to send the result to.

   // Okay, so point in hand is now obvious.  We need to actually
   // implement the video and audio/disk counters first before we can
   // implement the DRAM access requests.

   always @(negedge n_res) begin
      vidreg <= 0;
   end

   always @(posedge clk) begin
      if (n_res) begin
      end
      else
	; // Nothing to be done during RESET.
   end
endmodule

// TODO: Video and audio/disk timers.  This is the core logic where we
// determine where we are on the screen, which buffer address to fetch
// next, and so on.
module avtimers ();
endmodule

/* TODO: Summary of what is missing and left to implement: DRAM
   initialization pulses, DRAM refresh, video, disk, and audio
   scanout, SCSI DMA, EXTDTK yielding, double-check SCC read/write
   logic.  */

/*

TODO: Okay, we really have a plan now to try to make my code modular
and easy to understand.  The original probably wasn't too nice since
it was only written by really one person working by themself, but hey,
let's go better a second time around.  So, yes, this is the plan.  See
that nice, clean, simple DRAM controller main state advancement
module?  My goal is to create just a series of modules like that, they
plug together to create the full integrated system.  We use
combinatorial logic and rerouting wires as necessary to get the final
intended behavior.

One thing to remember is that we have monopoly control over the output
logic of RA7 and RA9.  We never need to yield high-impedance on this.
So we just use combinatorial logic to set this as we please, from
jumpers, internal registers, and the like.  Yes, namely the configured
installed RAM mode.

To keep the main DRAM controller simple, we can use combinatorial
logic spelled out separately and `n_cas` as a register to trigger the
proper CAS lines on the individual DRAM SIMMs.  This is also where we
handle *LDS and *UDS.

Since we use a module for the DRAM controller main loop, we can use
wires and other modules to feed it whatever state advancement clock we
want.  That's really good!  That solves a problem I was worrying
about.

*/
