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

`ifndef BBU_V
`define BBU_V

`include "common.vh"

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

// Please note: If we don't list the configuration in one of the
// following the tables, it's not supported by the BBU.  The BBU is a
// gate array, not a microcontroller!

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
 
   Undocumented signal but assumed to exist:

   64KRAM: Here we assign it to pin 21 for our own experimentation, a
   pin that is specified as just tied to ground.
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

   // The Macintosh SE deprecated SNDPG2.  Nevertheless... for the
   // sake of possibly making quasi-hardware replicas of earlier
   // Macintosh computers easier, we will preserve an implementation
   // here anyways.

   // Essential sequential logic RESET and clock signals
   input wire n_res; // *RESET signal
   input wire c16m;  // 15.667200 MHz master clock input
   output wire c8m;   // 7.8336 MHz clock output
   output wire c3_7m; // 3.672 MHz clock output
   output wire c2m;   // 1.9584 MHz clock output

   // RAM configuration pins
   input wire row2;    // 1/2 rows of RAM SIMMs jumper
   input wire mbram;   // 256K/1MB RAM SIMMs jumper
   input wire s64kram; // DOUBLY UNDOCUMENTED 64K RAM SIMMs jumper

   // MC68000 signals
   input wire a9, a17, a19, a20, a21, a22, a23;
   input wire r_n_w, n_as, n_uds, n_lds;
   `output_wz wire n_dtack;
   output wire n_ipl0;
   input wire n_ipl1;
   output wire n_berr;
   input wire n_vpa;

   // DRAM signals
   inout wire ra0, ra1, ra2, ra3, ra4, ra5, ra6, ra8;
   output wire ra7, ra9;
   output wire n_cas1l, n_cas0l, ram_r_n_w, n_ras, n_cas1h, n_cas0h;
   inout wire rdq0, rdq1, rdq2, rdq3, rdq4, rdq5, rdq6, rdq7,
	      rdq8, rdq9, rdq10, rdq11, rdq12, rdq13, rdq14, rdq15;
   output wire n_en245, n_pmcyc;

   // ROM and memory overlay signals
   output wire n_romen;

   // VIA signals
   output wire via_cs1;
   input wire n_viairq;

   // Video signals
   input wire vidpg2;  // VIDPG2 signal
   output wire vidout;  // VIDOUT signal
   output wire n_hsync; // *HSYNC signal
   output wire n_vsync; // *VSYNC signal

   // Sound and disk speed signals
   input wire sndres;
   output wire snd, pwm;
   // IWM signals
   output wire n_iwm;
   // SCC signals
   output wire n_sccen, n_sccrd, n_iow;
   // SCSI signals
   output wire n_scsi;
   input wire scsidrq;
   output wire n_dack;
   // PDS signals
   input wire n_extdtk;
   output reg n_earen; // ??? Purpose unknown.

   // Full DRAM address bus snooping?  I almost thought this was
   // required to implement some functions, but it turns out it isn't,
   // partial address bus snooping is good enough.  Nevertheless, I'll
   // preserve the implementation as it could be useful for BBU mods.
   reg [7:0] row_snoop; reg [7:0] col_snoop;

   // Installed RAM size.
   wire [23:0] ramsz;

   wire n_dtack_peri; // `*DTACK` for peripherals
   wire n_dtack_bbu; // Holds `*DTACK` high for BBU RAM accesses

   //////////////////////////////////////////////////
   // Pure combinatorial logic is defined first.

   // Assert `*IPL0` if we receive an interrupt signal from the VIA or
   // SCSI.  However, do not assert `*IPL0` if the SCC asserts
   // `*IPL1`.  Guide to the Macintosh family hardware, page 113.
   // SCSI interrupts are signaled only on IRQ from the SCSI
   // controller.  DRQ is not attached to MC68000 interrupt lines
   // whatsoever, it must be polled by software and is only used by
   // the BBU as specified in the other section.  TODO CONFIRM: The
   // SCSI IRQ line attaches directly to `*IPL0`?
   assign n_ipl0 = ~n_ipl1 | n_viairq;

   // Tri-state `*DTACK` when `*EXTDTK` is asserted.
   assign n_dtack = (n_extdtk) ? (n_dtack_peri | n_dtack_bbu) : 'bz;

   //////////////////////////////////////////////////
   // Sub-modules are instantiated here.

   // The remainder of definitions are for sequential logic.
   always @(negedge n_res) begin
      // Initialize all output registers on RESET.
      n_earen <= 1;
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
module clock_div (n_res, c16m, c8m, c3_7m, c2m_e);
   input wire n_res;
   input wire c16m;
   output reg c8m;
   output reg c3_7m;
   // c2m is now controlled by the DRAM controller state machine.
   // This is just an I/O argument placeholder.  We still generate the
   // signal internally, though.
   input wire c2m_e;

   /* Inside Macintosh claims that the serial clock is 3.672 MHz.
      Clock multiplication (via PLL) and division can be used to
      generate this from the 15.6672 MHz clock as follows:

      15.6672 / 3.6720 = 9792/2295 = (51*2^6*3)/(51*3^2*5)
      = (2^6)/(3*5) = 64/15

      This would entail a PLL clock running at 235.008 MHz inside the
      BBU, which was impractical for the technology available during
      the 1980s.  But if that were configured, a simple divide-by-64
      frequency counter would yield a perfect clock signal.

      As it turns out, the actual Macintosh did not use a true,
      constant-period 15.6672 MHz clock, but rather a 3.686 MHz clock
      with a phase/period error of up to 1 clock cycle of the 15.6672
      MHz clock.  Sequential logic is used to effect a principal
      divide-by-four clock cycle format, and at every fourth 3.686 MHz
      clock cycle, one extra 15.6672 MHz clock cycle is slipped in on
      the last low-edge half-period of the 3.686 MHz clock.  Over a
      long period of time, this effects an average frequency division
      factor of 4.25.

      And yes, even with that introduced phase/period error, the
      downstream hardware apparently still works just fine, thanks to
      the divide-by-16 in front of the SCC's internal baud rate
      generator.  This gives you a max baud of 230.4 kbits/sec, with a
      phase/period error of 1/(16*16) = 0.39%.  This is the same baud
      as AppleTalk.  */

   // TODO EVALUATE: Optimize this to minimize the number of register
   // bits required, while still preserving ideal frequency division
   // and synchronization behavior.  Maybe not... less registers
   // entails more combinatorial logic delay.

   // We use shift registers or 1-bit inverters for high performance,
   // minimal cycle overhead.
   reg c16m_div4_cntr; // C16M / 4 counter
   // Complex C16M -> C3_7M divider counter, principal divide-by-4
   reg c16m_div4_0_cntr;
   // Complex C16M -> C3_7M divider counter, counter for slipping in
   // extra cycle
   reg [16:0] c16m_div4_25_cntr;
   reg [3:0] c16m_div8_cntr; // C16M / 8 counter
   reg [7:0] c16m_div16_cntr; // C16M / 16 counter
   reg c4m;
   reg c2m;
   reg c1m;

   // assign c2m_e = c2m;

   always @(negedge n_res) begin
      // Initialize all output registers on RESET.
      c8m <= 0;
      c4m <= 0;
      c3_7m <= 0;
      c2m <= 0;
      c1m <= 0;

      // Initialize all internal registers on RESET.
      c16m_div4_cntr <= 0;
      c16m_div4_0_cntr <= 0;
      c16m_div4_25_cntr <= 1;
      c16m_div8_cntr <= 1;
      c16m_div16_cntr <= 1;
   end

   always @(posedge c16m) begin
      if (n_res) begin
	 c8m <= ~c8m;
	 if (c16m_div4_cntr) c4m <= ~c4m;
	 c16m_div4_cntr <= ~c16m_div4_cntr;
	 if (~c16m_div4_25_cntr[16]) begin
	    if (c16m_div4_0_cntr) c3_7m <= ~c3_7m;
	    c16m_div4_0_cntr <= ~c16m_div4_0_cntr;
	 end
	 // else Slip in the extra cycle by not incrementing the
	 // principal divide-by-4 counter.
	 c16m_div4_25_cntr <= { c16m_div4_25_cntr[15:0],
				c16m_div4_25_cntr[16] };
	 if (c16m_div8_cntr[3]) c2m <= ~c2m;
	 c16m_div8_cntr <= { c16m_div8_cntr[2:0], c16m_div8_cntr[3] };
	 if (c16m_div16_cntr[7]) c1m <= ~c1m;
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
             `ramsz_128k
          : // 2 rows of RAM SIMMs
             `ramsz_256k
       : (~mbram) ? // 256K RAM SIMMs
          (~row2) ? // 1 row of RAM SIMMs
             `ramsz_512k
          : // 2 rows of RAM SIMMs
             `ramsz_1m
       : // 1MB RAM SIMMs
          (~row2) ? // 1 row of RAM SIMMs
             `ramsz_2m
          : // 2 rows of RAM SIMMs
             `ramsz_4m
   ;

   assign ramsz_en
      = (s64kram) ? // 64K RAM SIMMs
          (~row2) ? // 1 row of RAM SIMMs
             `RAMSZ_EN_128K
          : // 2 rows of RAM SIMMs
             `RAMSZ_EN_256K
       : (~mbram) ? // 256K RAM SIMMs
          (~row2) ? // 1 row of RAM SIMMs
             `RAMSZ_EN_512K
          : // 2 rows of RAM SIMMs
             `RAMSZ_EN_1M
       : // 1MB RAM SIMMs
          (~row2) ? // 1 row of RAM SIMMs
             `RAMSZ_EN_2M
          : // 2 rows of RAM SIMMs
             `RAMSZ_EN_4M
   ;

   assign vid_main_addr
      = (s64kram) ? // 64K RAM SIMMs
          (~row2) ? // 1 row of RAM SIMMs
             `vid_main_addr_128k
          : // 2 rows of RAM SIMMs
             `vid_main_addr_256k
       : (~mbram) ? // 256K RAM SIMMs
          (~row2) ? // 1 row of RAM SIMMs
             `vid_main_addr_512k
          : // 2 rows of RAM SIMMs
             `vid_main_addr_1m
       : // 1MB RAM SIMMs
          (~row2) ? // 1 row of RAM SIMMs
             `vid_main_addr_2m
          : // 2 rows of RAM SIMMs
             `vid_main_addr_4m
   ;

   assign vid_alt_addr
      = (s64kram) ? // 64K RAM SIMMs
          (~row2) ? // 1 row of RAM SIMMs
             `vid_alt_addr_128k
          : // 2 rows of RAM SIMMs
             `vid_alt_addr_256k
       : (~mbram) ? // 256K RAM SIMMs
          (~row2) ? // 1 row of RAM SIMMs
             `vid_alt_addr_512k
          : // 2 rows of RAM SIMMs
             `vid_alt_addr_1m
       : // 1MB RAM SIMMs
          (~row2) ? // 1 row of RAM SIMMs
             `vid_alt_addr_2m
          : // 2 rows of RAM SIMMs
             `vid_alt_addr_4m
   ;

   assign snddsk_main_addr
      = (s64kram) ? // 64K RAM SIMMs
          (~row2) ? // 1 row of RAM SIMMs
             `snddsk_main_addr_128k
          : // 2 rows of RAM SIMMs
             `snddsk_main_addr_256k
       : (~mbram) ? // 256K RAM SIMMs
          (~row2) ? // 1 row of RAM SIMMs
             `snddsk_main_addr_512k
          : // 2 rows of RAM SIMMs
             `snddsk_main_addr_1m
       : // 1MB RAM SIMMs
          (~row2) ? // 1 row of RAM SIMMs
             `snddsk_main_addr_2m
          : // 2 rows of RAM SIMMs
             `snddsk_main_addr_4m
   ;

   assign snddsk_alt_addr
      = (s64kram) ? // 64K RAM SIMMs
          (~row2) ? // 1 row of RAM SIMMs
             `snddsk_alt_addr_128k
          : // 2 rows of RAM SIMMs
             `snddsk_alt_addr_256k
       : (~mbram) ? // 256K RAM SIMMs
          (~row2) ? // 1 row of RAM SIMMs
             `snddsk_alt_addr_512k
          : // 2 rows of RAM SIMMs
             `snddsk_alt_addr_1m
       : // 1MB RAM SIMMs
          (~row2) ? // 1 row of RAM SIMMs
             `snddsk_alt_addr_2m
          : // 2 rows of RAM SIMMs
             `snddsk_alt_addr_4m
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
   surrounded with invalid address guard zones... these are simply
   available for use by PDS expansion cards:

   * 0x000000 - 0x3fffff: RAM/ROM (switches based on overlay)
   * 0x400000 - 0x4fffff: ROM
   * 0x580000 - 0x5fffff: 5380 NCR/Symbios SCSI peripherals chip
   * 0x600000 - 0x7fffff: RAM, boot-time overlay only
   * 0x900000 - 0x9fffff: Zilog 8530 SCC (Serial Control Chip) Read
   * 0xb00000 - 0xbfffff: Zilog 8530 SCC (Serial Control Chip) Write
   * 0xd00000 - 0xdfffff: IWM (Integrated Woz Machine; floppy)
   * 0xe80000 - 0xefffff: Rockwell 6522 VIA
   * 0xf00000 - 0xffffef: ??? (the ROM appears to be accessing here)
   * 0xfffff0 - 0xffffff: Auto Vector

   This address map has also been confirmed with Guide to the
   Macintosh family hardware, page 127.  PLEASE NOTE: In SCC Read
   zone, if A0 == 1, then that is an SCC RESET.  IWM must be A0 == 1,
   VIA must be A0 == 0, SCC write must be A0 == 1.  SCSI read A0 == 0,
   SCSI write A0 == 1.

   SCC access notes: In the Macintosh Plus and older, even byte
   accesses are a read, odd byte accesses are a write.  Namely: `*LDS`
   == 0 == write, `*UDS` == 0 == read.  Remember, it's big endian.
   What about the separate address regions?  Well, I say just ignore
   those, it's there for a convenient convention, but it's not the
   officially documented hardware protocol.

   In the Macintosh SE, this behavior is somewhat changed.  Now `*IOW`
   controls both `*SCSI.IOW` and `*SCC.WR`, and `*SCCRD` is wired
   directly from the BBU to `*SCC.RD`.  `*UDS` is used to trigger
   `*SCSI.IOR`.

   PLEASE NOTE: Guide to the Macintosh family hardware, page 121.
   Rather than signaling bus errors for out of range RAM addresses,
   overflow accesses should just wrap around and repeat access to the
   same RAM.

   TODO FIXME: Guide to the Macintosh family hardware, page 127.
   Okay, so this is how to interpret the information about the
   boot-time overlay for the alternate RAM location.  Only a 2MB zone
   is exposed, even though you may have up to 4MB of RAM.  So, 2.5MB
   and 4MB RAM configurations need to be treated specially.  In
   particular, only the "upper row" of RAM is accessible greater than
   or equal to the address 0x680000.  Below that address, you get
   access to the first 512K of RAM.  Macintosh Plus actually uses the
   same overlay map too.  That's a defect in MESS/MAME source code but
   apparently it's not important, interestingly enough.  Okay, I guess
   I don't really quite understand, though, sorry.  Okay, this means,
   the first row, right?  "If 2.5 or 4 MB only upper row is
   accessible" page 127.

   ----------

   But, for the sake of Macintosh Plus recreation, please note.

   Guide to the Macintosh family hardware, page 122.  For the
   Macintosh Plus: "A word-wide access to any SCC address causes a
   phase shift in the processor clock, and is used by the operating
   system to correct the phase when necessary."

   "At system startup, the operating system reads an address in the
   range $F0 0000 through $F7 FFFF (labeled _Phase read_ in figures
   3-1 and 3-2) to determine whether the computer's high-frequency
   timing signals are correctly in phase.  When the timing signals are
   not in phase, RAM accesses are not timed correctly, causing an
   unstable video display, RAM errors, and VIA errors."  Well, I can
   see how that would be happening with just a bunch of PALs, but I
   don't think it still needs to be that way when you have the BBU in
   charge, you can do better!  And indeed, that note only appears to
   apply to the Macintosh Plus, not the Macintosh SE, as it is listed
   in that section.

   The TSG PAL places one of the high-frequency phase indicator
   signals on D0 of the address bus, I assume it is the 1 MHz *PMCYC
   signal.  A multiple address read instruction is used to read three
   consecutive data values from the address bus in synchronous I/O
   mode (due to using address 0xf00000), so each address read is
   either 10 or 20 CPU cycles long.  This will sample the phase at a
   few different points.  The phase readings are added together, if
   they are zero or one, then we are "in-phase."  Otherwise, phase
   readings 2 and 3 are considered "out-of-phase" so we access a
   word-width address in the SCC range to shift the high frequency
   timing by 128 ns (one CPU clock cycle at 8 MHz).

   The important thing to remember is that every MC68000 instruction
   executes for an even number of clock cycles (divisible by 2), and
   there is no pipelining in these early CPUs.
*/
module decode_devaddr (n_res, c16m, n_ramen, n_romen, n_scsi, scsidrq,
		       n_dack, n_sccen, n_sccrd, n_iow, n_iwm, via_cs1,
		       n_vpa, n_berr, n_as, a23_19, a9, n_extdtk,
		       boot_overlay, r_n_w, reg_romen, reg_ram_w,
		       n_dtack_peri);
   input wire n_res;
   input wire c16m;
   output wire n_ramen;
   output wire n_romen;
   output wire n_scsi;
   input wire scsidrq;
   output wire n_dack;
   output wire n_sccen;
   output wire n_sccrd;
   output wire n_iow;
   output wire n_iwm;
   output wire via_cs1;
   output wire n_vpa;
   output wire n_berr;
   input wire n_as;
   input wire [4:0] a23_19;
   input wire a9;
   input wire n_extdtk;
   input wire boot_overlay;
   input wire r_n_w;
   // Have we attempted to write to the regular RAM address zone?
   output wire reg_ram_w;
   // Has an address access to the regular *ROMEN zone occurred?  This
   // signal is used to disable the boot-time memory overlay.
   output wire reg_romen;
   output wire n_dtack_peri; // `*DTACK` for peripherals

   wire reg_ram, reg_ram_r;
   wire scdma; // host requested performing a SCSI pseudo-DMA read/write
   wire scsi, sccrd, sccwr;
   wire berr_scc;

   reg [31:0] berr_cntr; // Counter to trigger `*BERR` after 265 ms

   // If the boot-time overlay is enabled but we attempt to write to
   // the regular RAM region, then this is a `*RAMEN` trigger.  The
   // overlay control logic will zero the switch on the next cycle,
   // but we use combinatorial logic here to act immediately.
   assign reg_ram = ~n_as & (a23_19[4:3] == 2'b00);
   assign reg_ram_r = (r_n_w & reg_ram);
   assign reg_ram_w = (~r_n_w & reg_ram);
   assign n_ramen = ~((boot_overlay) ?
		      ((~n_as & ((a23_19[4:1] == 4'h6) |
				 (a23_19[4:1] == 4'h7))) | reg_ram_w) :
		    reg_ram);
   assign reg_romen = ~n_as & (a23_19[4:1] == 4'h4);
   // Only trigger `*ROMEN` for reads, not writes, in overlay zone.
   assign n_romen = ~(reg_romen | (boot_overlay & reg_ram_r));
   assign scsi    = ~n_as & (a23_19[4:0] == 5'b01011);
   // Note that the SCSI chip enable is NOT asserted in pseudo-DMA
   // access mode, which is indicated by A9 (add decimal 512 to base
   // address).
   assign scdma   = scsi & a9;
   // assign n_scsi  = ~(scsi & ~scdma);
   assign n_scsi  = ~(scsi & ~a9); // simplification
   // N.B.: One idea I had was to use a timer to de-assert `*DACK` to
   // ensure it is not held too long.  For now I am assuming this is
   // not necessary given the MC68000 address bus speed.
   assign n_dack  = scdma & scsidrq;
   assign sccrd   = ~n_as & (a23_19[4:1] == 4'h9);
   assign sccwr   = ~n_as & (a23_19[4:1] == 4'hb);
   assign n_sccen = ~(sccrd | sccwr);
   assign n_sccrd = ~sccrd;
   assign n_iow   = ~((scsi & ~r_n_w) | sccwr);
   assign n_iwm   = ~(~n_as & (a23_19[4:1] == 4'hd));
   assign via_cs1 =  ~n_as & (a23_19[4:0] == 5'b11101);
   // The signal *VPA is asserted in address range 0xe00000 -
   // 0xffffff.  This is for synchronous I/O devices accessed in the
   // old 6800 fashion.
   assign n_vpa   = ~(~n_as & ((a23_19[4:1] == 4'he) |
			       (a23_19[4:1] == 4'hf)));
   // N.B.: According to Guide to the Macintosh family hardware, page
   // 126, the implementation of Auto Vector is easy and
   // straightforward for the BBU.  Just assert `*VPA` in the address
   // range.  The CPU sets address lines A3 - A1, and this causes the
   // CPU to automatically jump to the memory location containing the
   // interrupt handler.

   // Optionally trigger bus errors if a read is attempted from the
   // write-only SCC address space, and vice versa.
   assign berr_scc = (sccrd & ~r_n_w) | (sccwr & r_n_w);

   // Here's the rule on asserting `*BERR`, Guide to the Macintosh
   // Family hardware, page 126: "If any access has not terminated
   // within 265 ms, the BBU asserts the bus error signal /BERR."  In
   // practice, this would possibly only occur for PDS and SCSI
   // accesses.
   assign n_berr = ~(berr_cntr >= 4240000);

   // NOTE: For all peripherals, we must set `*DTACK` from the BBU
   // upon successful access condition and time durations because it
   // is not set by the device itself.  From the time *AS is asserted,
   // we simply wait one clock cycle on whatever clock is given to us
   // before we trigger *DTACK for the peripheral.

   // N.B.: According to Guide to the Macintosh family hardware,
   // `*DTACK` is not used to respond to addresses in the range
   // 0xe00000 - 0xffffff, only below that.  `*VPA` alone is used to
   // respond to these addresses.  Except for the case of SCSI
   // pseudo-DMA accesses, we only assert `*DTACK` when we assert
   // `*DACK`.
   assign n_dtack_peri = n_as | ((n_vpa | scdma) & n_dack);

   // N.B. For now, we leave it to higher level logic to put on
   // `*DTACK` on high-impedance when `*EXTDTK` is asserted.

   // assign n_dtack_peri =
   //   (n_extdtk) ? (n_as | ((n_vpa | scdma) & n_dack)) : 'bz;

   always @(negedge n_res) begin
      berr_cntr <= 0;
   end

   always @(posedge c16m) begin
      if (n_res) begin
	 if (n_as)
	   berr_cntr <= 0;
	 else begin
	    if (berr_cntr < 4240000) // # of 16 MHz pulses in 265 ms
	      berr_cntr <= berr_cntr + 1;
	    else
	      ; // Nothing to be done.
	 end
      end
      else
	; // Nothing to be done during RESET.
   end
endmodule

// Boot-time memory overlay register and controlling logic.  This is
// fairly straightforward to implement once you see all the other
// logic of the BBU in place.
module overlay_logic (n_res, clk, boot_overlay, reg_romen, reg_ram_w);
   input wire n_res;
   input wire clk;
   // Boot-time memory overlay switch, 1 = enable, 0 = disable.
   output reg boot_overlay;
   input wire reg_romen;
   input wire reg_ram_w;

   always @(negedge n_res) begin
      // Initialize the overlay switch to ENABLED on RESET.
      boot_overlay <= 1;
   end

   always @(posedge clk) begin
      if (n_res) begin
	 // Disable the overlay on the first access to the regular ROM
	 // address zone.  And, according to MESS/MAME, also disable
	 // on the first attempt to write the regular RAM zone.
	 if (reg_romen | reg_ram_w)
	   boot_overlay <= 0;
	 else
	   ; // Nothing to be done.
      end
   end
endmodule

// Column address strobe decode logic.  Determine which column access
// strobe line to assert based off of the installed RAM, high-order
// CPU address lines, and *UDS/*LDS signals.
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
       (~cas_n_ras) ? a9 : a17
   ;
   assign ra9
     = (mbram) ? // 1MB RAM SIMMs
       (~cas_n_ras) ? a19 : a20
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

// TODO: So this is how the fastest CPU access state machine workss.
// *AS is started to be asserted on the rising edge of the CPU clock
// at S2, but it is not guaranteed clearly asserted until the falling
// edge of S2.  Between this time, we must assert *DTACK before the
// falling edge of S4.  So yes, we effectively have a maximum of two
// 16 MHz cycles to react, but better if we can get it done in 1.5
// cycles at 16 MHz.  We must assert *DTACK before 10 ns of the end,
// so better to go 30 ns before the end, i.e. half of a 16 MHz clock
// cycle.

// So, point in hand, we need to design our logic to work very fast
// within these constraints.  First, we have a cycle counter runs on
// the _falling edge_ of the clock.  We only count one.  Then, we have
// a "subcycle counter" which is really just combinatorial logic.  We
// must only use combinatorial logic in order to be able to assert
// signals sub-cycle in a way that hopefully still works on an FPGA.
// If this really only works on an ASIC, though, our next best option
// is to use a 32 MHz PLL to satisfy the timing requirements.  Also,
// it's important to understand, when using combinatorial logic to
// effectively double the clock frequency, understanding signal
// propagation delay is critical.

// Here, we assume the rising edge of C16M is synced to the rising
// edge of C8M, otherwise this won't work!

// There's good reason to be concerned about glitching when not using
// register-buffered outputs on a sequential clock.  But, yeah,
// hardware-wise, this is the simplest way to do clock frequency
// doubling, and if it works like the 3.686 MHz clock with
// phase/period error, history be told.  F.Y.I. Anecdotal evidence
// hints that the Macintosh Plus may have used this combinatorial
// logic hackery on clock signals in its PALs.  But it was still
// driven by clock C16M and was a registered PAL?  Maybe I better just
// look down its datasheet real good, check that it uses typical
// latching.  PAL16R4.

// Okay, here's the deal.  We can get this to work reasonably without
// glitching through the means of programmable slew rate limiting
// filter circuits built into the FPGA at the pin terminals.  But that
// is the necessity if we go that path.

module dram_fast_test (c16m, c8m, n_res, n_as);
   input wire c16m;
   input wire c8m;
   input wire n_res;
   input wire n_as;

   reg state_buf;
   wire state0, state1, state2, state3;
   // wire state4;

   assign state0 = n_as;
   assign state1 = ~n_as & ~state_buf &  c16m & ~c8m;
   assign state2 = ~n_as & ~state_buf & ~c16m & ~c8m;
   assign state3 = ~n_as &  state_buf &  c16m &  c8m;
   // assign state4 = ~n_as &  state_buf & ~c16m &  c8m;

   always @(negedge n_res) begin
      state_buf <= 0;
   end

   always @(posedge c16m) begin
      if (n_res) begin
	 if (~n_as)
	   state_buf <= 1;
	 else
	   state_buf <= 0;
      end
   end
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
   // *PMCYC principally enables the row/column address multiplexers.
   // At a higher level, it is used to determine whether it is the
   // CPU's turn to access RAM or the BBU's turn to access RAM.  The
   // CPU always takes a multiple of 4 clock cycles running at 8 MHz
   // to access RAM.  In the Macintosh Plus, this signal was wired up
   // to a 1 MHz clock, but the Macintosh SE uses a more sophisticated
   // approach.
   // TODO FIXME: Implement `*PMCYC` generation logic, comes from the
   // video timers module.
   input wire n_pmcyc;
   // output reg n_pmcyc;
   output reg n_dtack;

   input wire [9:0] ra; // RAM Address (RA)
   // In order to implement the memory overlay switch, we must snoop
   // the address bus.  These are the registers we use to store the
   // address multiplexer outputs.
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
	    //    // Enable the row address multiplexers.
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
	       // Enable the column address multiplexers.
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
   // *PMCYC principally enables the row/column address multiplexers.
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

   // TODO FIXME Important!  High speed control for column access
   // strobes?  The Macintosh 128K and Macintosh Plus use
   // combinatorial logic to assert the *CAS signal for half of a C16M
   // clock cycle, one pulse.

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
	       // Enable the row address multiplexers.
	       ra <= row_addr;
	       drc_state_buf <= drc_state << 1;
	    end
	    if (drc_state[2]) begin // State 4
	       // Trigger *RAS.
	       n_ras <= 0;
	       drc_state_buf <= drc_state << 1;
	    end
	    if (drc_state[3]) begin // State 8
	       // Enable the column address multiplexers.
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

// TODO FIXME: We must be able to support Fast Page Mode (FPM) for
// video memory access too.  But we don't do this for the sound
// buffer.
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
   input wire n_res;
   input wire c16m;

   input wire c8m;
   input wire c4m;
   input wire c2m;
   input wire c1m;

   input wire [23:0] vid_main_addr; // Address of main video buffer
   input wire [23:0] vid_alt_addr;  // Address of alternate video buffer
   input wire [23:0] snddsk_main_addr; // Address of main sound/disk buffer
   // Address of alternate sound/disk buffer
   input wire [23:0] snddsk_alt_addr;

   // Video signals
   input wire vidpg2;  // VIDPG2 signal
   output wire vidout;  // VIDOUT signal
   output wire n_hsync_pt; // *HSYNC pre-trigger
   output reg n_hsync; // *HSYNC signal
   output reg n_vsync; // *VSYNC signal

   // Sound and disk speed signals
   input wire sndres;
   output reg snd, pwm;

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
   wire [4:0] c16m_cntr;      // 16 MHz sub-cycle counter
   reg n_ldps;
   reg slice_cntr;            // Used to alter carry propagation
   reg [14:0] va;             // Video address counter

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

   // Important!  Main screen/sound buffers are selected when the VIA
   // bit is one, alternate when the VIA bit is zero.  These are
   // treated as active low signals.

   reg [15:0] snddsk_reg; // PCM sound sample and disk speed register

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

   // N.B. Sound generation.  Since the original Macintosh used only
   // simple counters and the registered ASG PAL for PWM generation,
   // there is no way the more sophisticated PWM techniques could have
   // been used.  This is going to be a one-shot countdown timer for
   // generating a single pulse per byte.

   // The current 16 MHz cycle # can easily be determined from our
   // divided clock frequencies.
   assign c16m_cntr = { c1m, c2m, c4m, c8m };
   assign vidout = vidout_sreg[15];

   always @(negedge n_res) begin
      // Initialize all output registers on RESET.

      n_hsync <= 1; n_vsync <= 1;

      snd <= 0; pwm <= 0;

      // Initialize all internal registers on RESET.
      vidout_sreg <= 0;
      va <= 0;
      snddsk_reg <= 0;
   end

   // N.B. Now this is tricky.  Our load pixel shifter is carefully
   // timed to happen immediately after the last pixel is displayed
   // and as soon as the next value is available from DRAM.  This
   // means that we actually offset the horizontal blanking signal by
   // a nominal amount in comparison to the video address counter
   // increments to compensate.

   // Okay, here's the trick with FPM fetches.  We still need to count
   // by 16 on the video address so we can time the 16-bit sound load
   // at the end of the cycle correctly, but we use a double-width
   // video shift register and only trigger video load half as often.

   always @(posedge c16m) begin
      if (n_ldps) begin
	 // Fill the least significant bit with logic one so that the
	 // CRT beam is off during blanking.
	vidout_sreg <= { vidout_sreg[14:0], 1'b1 };
      end
      else
	vidout_sreg <= 0; // TODO load new value.

      // Increment the video address on every 1 MHz clock cycle.
      // However, on horizontal blanking, we slice the carry until the
      // end of the interval.
      if (c16m_cntr == 4'hf) begin
	 // N.B.: Remember we are counting by 16-bit words.
	 if (slice_cntr)
	   va[4:0] <= va[4:0] + 2;
	 else
	   va <= va + 2;
      end
   end
endmodule

/* TODO: Summary of what is missing and left to implement: DRAM
   initialization pulses, DRAM refresh, detect 2.5MB of RAM and
   configure address buffers accordingly, video, disk, and audio
   scanout.

   Okay, so the VERDICT on DRAM initialization pulses.  We don't
   actually use these as we should, strictly speaking, but why does it
   still work?  On power-on RESET, the first few CPU memory accesses
   are all in ROM.  Yet the BBU is still scanning the DRAM and
   fetching words from it.  These first few words will be garbage, but
   it's okay because we're read-only.  By the time the CPU makes its
   first write to DRAM, all is well because it received a sufficient
   number of *RAS initialization pulses.

   So really, the only mysteries left now is 2.5MB RAM detection and
   4MB RAM DRAM refresh.  Then we need to do the busywork to implement
   the PWM and video scanout modules and we're done!  */

`endif // NOT BBU_V
