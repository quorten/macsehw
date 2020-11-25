/* Implementation of Macintosh 128k/512k PALs in Verilog,
   mainly to assist verification of the Macintosh SE BBU.  They are
   not identical, of course, but this should at least be helpful is
   spotting significant flaws.

   Note that the signal names use here are the same as used in the
   Unitron Macintosh clone's reverse engineering documentation.  Many
   of the signals are active low but not indicated here, for now.

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

/* Note: All arguments are listed in the order of the pinout of each
   PAL chip.

   Another point, our cheap and easy way to hand self-referential PAL
   logic equations is to simply treat them as registered sequential
   logic equations and use enough simulation sub-cycles on them for
   them to reach settle time.   `simclk` controls these sub-cycles.
 
   Also note, PAL registers do not have a deterministic
   initialization, hence the absence of a RESET signal.
*/

`ifndef MAC128PAL_V
`define MAC128PAL_V

`include "common.vh"

// PAL0-16R4: Timing State Machine
module tsm(simclk, n_res,
	   clk, sysclk, pclk, s1, ramen, romen, as, uds, lds, gnd,
	   oe1, casl, cash, ras, vclk, q2, q1, s0, dtack, vcc);
   input `virtwire simclk, n_res;
   input wire clk;
   input wire sysclk, pclk, s1, ramen, romen, as, uds, lds;
   `power wire gnd;
   input wire oe1;
   output `simwire casl, cash;
   output reg ras, vclk, q2, q1;
   output `simwire s0, dtack;
   `power wire vcc;

   // We must implement RESET for simulation or else this will never
   // stabilize.
   always @(negedge n_res) begin
      casl <= 0; cash <= 0; s0 <= 0; dtack <= 0;

      ras <= 0; vclk <= 0; q2 <= 0; q1 <= 0;
   end

   // Simulate combinatorial logic sub-cycles.
   always @(posedge simclk) begin
      casl <= ~(~s0 & s1 & sysclk // video
		| ~s0 & ~ramen & ~lds // processor
		| ~s0 & ~casl & sysclk
		| pclk & ~casl);
      cash <= ~(~s0 & s1 & sysclk // video
		| ~s0 & ~ramen & ~uds // processor
		| ~s0 & ~cash & sysclk
		| pclk & ~cash);
      s0 <= ~(~ras & ~sysclk // 0 for `cas` and 1 for `ras` (counting with the delay of the PAL)
	      | ~ras & ~s0);
      dtack <= ~(~romen // if the ROM is 250 nS or SCC or IWM
		 | ~ras & ~ramen & ~s1 // guarantees that it will be recognized on the falling edge of `pclk` in state `s5`
		 | ~as & ~dtack & ramen // expects `as` to rise for disable
		 | ~as & ~dtack & ~s1); // but avoid video cycles (WE)
   end

   // Simulate registered logic.
   always @(posedge clk) begin
      ras <= ~(~pclk & q1 & s1 // video cycle
	       | ~pclk & q1 & ~ramen & dtack // processor cycle
	       | pclk & ~ras); // any other cycle
      vclk <= ~(~q1 & pclk & q2 & vclk // divide by 8 (1MHz)
		| ~vclk & q1
		| ~vclk & ~pclk
		| ~vclk & ~q2);
      q1 <= ~(~pclk & q1
	      | pclk & ~q1); // divide `pclk` by 2 (4MHz)
      q2 <= ~(~q1 & pclk & q2 // divide by 4 (2MHz)
	      | ~q2 & q1
	      | ~q2 & ~pclk);
   end
endmodule

// ras of processor: a16| a8| a7| a6| a5| a4| a3| a2| a1
// cas of processor: a17|a16|a15|a14|a13|a12|a11|a10| a9
// ras of video:     pup| v8| v7| v6| v5| v4| v3| v2| v1
// cas of video:     pup|pup|vpg|3q1|3q4|v12|v11|v10| v9
// ras of sound:     pup|3q4|v12|v11|v10|?v8|?v9| v7| v6
// cas of sound:     pup|pup|pup|spg|pup|spg|spg|spg|3q1

// PAL1-16R8: Linear Address Generator
module lag(simclk, n_res,
	   sysclk, p2io1, l28, va4, p0q2, vclk, va3, va2, va1,
	   gnd, oe2, vshft, vsync, hsync, s1, viapb6, snddma,
	   reslin, resnyb, vcc);
   input `virtwire simclk, n_res;
   input wire sysclk;
   input wire p2io1, l28, va4, p0q2, vclk, va3, va2, va1;
   `power wire gnd;
   input wire oe2;
   output reg vshft, vsync, hsync, s1, viapb6, snddma, reslin, resnyb;
   `power wire vcc;

   // We must implement RESET for simulation or else this will never
   // stabilize.
   always @(negedge n_res) begin
      vshft <= 0; vsync <= 0; hsync <= 0; s1 <= 0; viapb6 <= 0;
      snddma <= 0; reslin <= 0; resnyb <= 0;
   end

   // Simulate combinatorial logic sub-cycles.
   always @(posedge simclk) begin
   end

   // Simulate registered logic.
   always @(posedge sysclk) begin
      vshft <= ~(s1 & ~vclk & snddma); // one pulse on the falling edge of `vclk`
      vsync <= ~(reslin
		 | ~vsync & ~l28);
      hsync  <= ~(viapb6 & va4 & ~va3 & ~va2 & va1 // begins in 29 (VA5)
		  | /*~ ???*/resnyb
		  | ~hsync & viapb6); // ends in 0F
      s1 <= ~(~p0q2 // 0 for processor and 1 for video
	      | ~vclk
	      | ~vsync & hsync
	      | ~vsync & viapb6 // only in vertical retrace we have sound cycles
	      | ~viapb6 & hsync & ~va4 & ~va3 & ~va2
	      | ~viapb6 & ~hsync & (~va4 | va4 & ~va3 & ~va2 |
				    va4 & ~va3 & va2 & ~va1));
      viapb6 <= ~(~hsync & resnyb // 1 indicates horizontal retrace (pseudo VA6)
		  | va1 & ~viapb6
		  | va2 & ~viapb6
		  | ~hsync & ~viapb6
		  | resnyb & ~viapb6
		  | vshft & ~viapb6);
      snddma <= ~(viapb6 & va4 & ~va3 & va2 & va1 & p0q2 & vclk & ~hsync // 0 in this output
		  | ~snddma & vclk); // ... indicates sound cycle
      reslin <= ~(0); // ??? try to generate line 370
      resnyb <= ~(vclk // increment VA5:VA14 in 0F and 2B
		  | viapb6 // ???
		  | va1
		  | va2
		  | ~viapb6 & va3
		  | hsync
		  | viapb6 & ~va3
		  | ~hsync & va3 & ~va4
		  | ~hsync & ~va3 & va4);
   end
endmodule

// 32 active cycles for line  - UA6..UA1 = 0 to 1F
// 1 cycle for sound/PWM                 = 2B
// 11 cycles for retrace                 = 20 to 2A

// 342 active lines  - VA6..VA14 = 010011100 to 111110001
// 28 retrace lines              = 010000000 to 010011011

// PAL2-16L8: Bus Management Unit 1
module bmu1(simclk, n_res,
	    va9, va8, va7, l15, va14, ovlay, a23, a22, a21, gnd,
	    as, csiwm, rd, cescc, vpa, romen, ramen, io1, l28, vcc);
   input `virtwire simclk, n_res;
   input wire va9, va8, va7, l15, va14, ovlay, a23, a22, a21;
   `power wire gnd;
   input wire as;
   output `simwire csiwm, rd, cescc, vpa, romen, ramen, io1, l28;
   `power wire vcc;

   // We must implement RESET for simulation or else this will never
   // stabilize.
   always @(negedge n_res) begin
      csiwm <= 0; rd <= 0; cescc <= 0; vpa <= 0; romen <= 0;
      ramen <= 0; io1 <= 0; l28 <= 0;
   end

   // Simulate combinatorial logic sub-cycles.
   always @(posedge simclk) begin
      csiwm <= ~(a23 & a22 & ~a21 & ~as); // DFE1FF
      rd <= ~(a23 & ~a22 & ~a21 & ~as); // 9FFFF8
      cescc <= ~(a23 & ~a22 & ~as); // 9FFFF8(R) or BFFFF9(W)
      vpa <= ~(a23 & a22 & a21 & ~as); // above E00000 is synchronous
      romen <= ~(~a23 & a22 & ~a21 & ~as // 400000
		 | ~a23 & ~a22 & ~a21 & ~as & ovlay // (and 000000 with `ovlay`)
		 | a23 & ~a22 & ~as
		 | a23 & ~a21 & ~as); // for generating DTACK (not accessing ROM: A20)
      ramen <= ~(~a23 & ~a22 & ~a21 & ~as & ~ovlay // 000000
		 | ~a23 & a22 & a21 & ~as & ovlay); // (600000 with `ovlay`)
      io1 <= ~(0); // ???
      l28 <= ~(~l15 & ~va9 & ~va8 & va7 // reached 370 or we don't pass line 28
	       | ~l28 & ~va9
	       | ~l28 & ~va8
	       | ~l28 & ~va7);
   end
endmodule

// PAL3-16R4: Bus Management Unit 0
module bmu0(simclk, n_res,
	    sysclk, ramen, romen, va10, va11, va12, va13, va14, rw,
	    gnd, oe1, g244, we, ava14, l15, vid, ava13, servid, dtack, vcc);
   input `virtwire simclk, n_res;
   input wire sysclk;
   input wire ramen, romen, va10, va11, va12, va13, va14, rw;
   `power wire gnd;
   input wire oe1;
   output `simwire g244, we;
   output reg ava14, l15, vid, ava13;
   // N.B. Although this is nominally an output we can treat it as an
   // input?
   input wire servid, dtack;
   `power wire vcc;

   // We must implement RESET for simulation or else this will never
   // stabilize.
   always @(negedge n_res) begin
      g244 <= 0; we <= 0;

      ava14 <= 0; l15 <= 0; vid <= 0; ava13 <= 0;
   end

   // Simulate combinatorial logic sub-cycles.
   always @(posedge simclk) begin
      g244 <= ~(~ramen & rw
		| ~g244 & ~ramen);
      we <= ~(~ramen & ~rw
	      | ~we & ~dtack); // or `dtack` is shorter before the video cycle
   end

   // Simulate registered logic.
   always @(posedge sysclk) begin
      ava14 <= ~(~va14 & ~va13); // + 1
      l15 <= ~(~va14 & ~va13 & ~va12 & ~va11 & ~va10 // we haven't passed line 15
	       | va14 & ~va13 & va12 & va11 & va10); // passed by 368
      vid <= ~(servid); // here we invert: blanking is in `vshft`
      ava13 <= ~(va13); // + 1
   end
endmodule

// PAL4-16R6: Timing Signal Generator
module tsg(simclk, n_res,
	   sysclk, vpa, a19, vclk, p0q1, e, keyclk, intscc, intvia,
	   gnd, oe3, d0, q6, clkscc, q4, q3, viacb1, pclk, ipl0, vcc);
   input `virtwire simclk, n_res;
   input wire sysclk;
   input wire vpa, a19, vclk, p0q1, e, keyclk, intscc, intvia;
   `power wire gnd;
   input wire oe3;
   output `simwire d0;
   output reg q6, clkscc, q4, q3, viacb1, pclk;
   output `simwire ipl0;
   `power wire vcc;

   // We must implement RESET for simulation or else this will never
   // stabilize.
   always @(negedge n_res) begin
      d0 <= 0; ipl0 <= 0;

      q6 <= 0; clkscc <= 0; q4 <= 0; q3 <= 0; viacb1 <= 0;
      pclk <= 0;
   end

   // Simulate combinatorial logic sub-cycles.
   always @(posedge simclk) begin
      ipl0 <= ~intscc | intvia; // CORRECTION
      // ipl0 <= ~(0); // ??? /M nanda
      d0 <= ~(~vpa & ~a19 & e); // F00000 sample the phase with 0  /n e' + usado
   end

   // Simulate registered logic.
   always @(posedge sysclk) begin
      // TODO VERIFY: q6 missing?
      q6 <= ~(0);
      clkscc <= ~(clkscc & ~pclk & ~q4
		  | clkscc & ~pclk & ~q3
		  | clkscc & ~pclk & vclk
		  | ~clkscc & pclk
		  | ~clkscc & q4 & q3 & ~vclk); // skip one inversion every 32 cycles
      viacb1 <= ~(0); // ??? /M nanda
      pclk <= ~(pclk); // divide SYSCLK by 2 (8MHz)
      q3 <= ~(~vclk); // `sysclk` / 16
      q4 <= ~(q4 & q3 & ~vclk // `sysclk` / 32
	      | ~q4 & ~q3                       // } J for generating CLKSCC
	      | ~q4 & vclk);
   end
endmodule

/* Now in order to fully implement the Macintosh's custom board
   capabilities, we must as a baseline have an implementation of some
   standard logic chips that are found on the Macintosh Main Logic
   Board.  This is where we implement the modules.  */
`include "stdlogic.v"

// Wire that PAL cluster together, along with supporting standard
// logic chips.  Here, we try to better indicate active high and
// active low because we also need to stick in a hex inverter chip.
module palcl(simclk, vcc, gnd, n_res, n_sysclk,
	     sysclk, pclk, p0q1, clkscc, p0q2, vclk, q3, q4,
	     e, keyclk,
	     a23, a22, a21, a20, a19, a18, a17, a16,
	     a15, a14, a13, a12, a11, a10, a9,
	     a8, a7, a6, a5, a4, a3, a2, a1,
	     n_as, n_uds, n_lds, n_dtack, r_n_w,
	     d0, d1, d2, d3, d4, d5, d6, d7,
	     d8, d9, d10, d11, d12, d13, d14, d15,
	     casl, cash, ras, we,
	     ra0, ra1, ra2, ra3, ra4, ra5, ra6, ra7, ra8, ra9,
	     rdq0, rdq1, rdq2, rdq3, rdq4, rdq5, rdq6, rdq7,
	     rdq8, rdq9, rdq10, rdq11, rdq12, rdq13, rdq14, rdq15,
	     n_intscc, n_intvia, n_ipl0,
	     n_ramen, n_romen, n_csiwm, n_sccrd, n_cescc, n_vpa,
	     viapb6, ovlay, viacb1, n_sndpg2, n_vidpg2,
	     n_vsync, n_hsync, vid);
   input `virtwire simclk;
   `power wire vcc;
   `power wire gnd;
   input wire n_res;
   input wire n_sysclk; // 16MHz

   // Clocks
   // 8,4,3.686,2,1,1,0.5 MHz
   output wire sysclk, pclk, p0q1, clkscc, p0q2, vclk, q3, q4;
   input wire e; // 6800 synchronous I/O "E" clock, ~1MHz
   input wire keyclk;

   // MC68000 CPU address signals
   input wire a23, a22, a21, a20, a19, a18, a17, a16,
	      a15, a14, a13, a12, a11, a10, a9,
	      a8, a7, a6, a5, a4, a3, a2, a1;
   // not used: a18
   input wire n_as, n_uds, n_lds;
   output wire n_dtack;
   input wire r_n_w;
   inout wire d0, d1, d2, d3, d4, d5, d6, d7,
	      d8, d9, d10, d11, d12, d13, d14, d15;

   // DRAM signals
   output wire casl, cash, ras, we;
   output wire ra0, ra1, ra2, ra3, ra4, ra5, ra6, ra7, ra8, ra9;
   inout wire rdq0, rdq1, rdq2, rdq3, rdq4, rdq5, rdq6, rdq7,
	      rdq8, rdq9, rdq10, rdq11, rdq12, rdq13, rdq14, rdq15;

   // Interrupt signals
   input wire n_intscc, n_intvia;
   output wire n_ipl0;

   // Chip enable signals
   output wire n_ramen, n_romen, n_csiwm, n_sccrd, n_cescc, n_vpa;

   // VIA signals
   output wire viapb6; // horizontal blanking
   input wire ovlay; // Boot-time overlay
   output wire viacb1; // keyboard interrupt
   input wire n_sndpg2; // VIA PA3
   input wire n_vidpg2; // VIA PA6
   // wire d0; // Video timing phase sense signal

   // Video control signals
   output wire n_vsync, n_hsync, vid;

   // Internal video address signals, comes from video counter IC
   wire va14, va13, va12, va11, va10, va9, va8, va7,
	va6, va5, va4, va3, va2, va1;
   // Incremented high-order video address lines
   wire ava14, ava13;
   // Internal video signals
   wire n_vshft, n_snddma, n_servid;

   // Address multiplexer signals?
   wire s0, s1, l28, l15, n_245oe;

   // PAL chip-select and unknown "IO" signals
   wire tsm_oe1, lag_oe2, bmu0_oe1, tsg_oe3;

   // Internal PAL cluster use only, supports video
   wire reslin, resnyb; // video counter controllers?
   wire p2io1, q6;

   // Wires to/from standard logic chips.
   wire snddma, n_a20, n_sndres, sndres, n_snd, snd, wr, n_wr;

   // N.B.: *WR comes from IWM chip, WR goes to floppy drives.  *A20
   // goes to VIA.CS1.  *SNDDMA comes from the LAG.  *SYSCLK comes
   // from the 16MHz crystal oscillator.  SND comes from the dual PWM
   // disk driver counters.

   wire n_dmald; // *DMALD is generated by ASG.

   wire c8mf, c16mf, c2m, u12f_tc, ram_r_n_w_f;
   wire vmsh; // video mid-shift, connect two register chips together

   wire s5; // Video shift register final output

   // L12 => va13
   // L13 => va14
   // va12 => ava13
   // va13 => ava14
   // n_ldps => n_vshft
   // VID/*u => s1 
   // tc => vclk

   // TODO FIXME!  We're not using assign correctly!  `assign` implies
   // diode isolation between separate nets.  We want to merge
   // multiple names together for the same net.

   // N.B. on PCB, use c8mf for high-frequency signal
   // filter/conditioning, we add a resistor.
   assign c8mf = pclk;
   assign c16mf = sysclk;
   assign ram_r_n_w_f = we;
   assign c2m = p0q2;

   // TSEN0: 150 ohm resistor to GND for PAL for TSM and BMU0.
   assign tsm_oe1 = gnd;
   assign bmu0_oe1 = gnd;
   // TSEN1: 150 ohm resistor to GND for LAG.
   assign lag_oe2 = gnd;
   // TSG Output Enable is controlled by CAS on Macintosh Plus,
   // otherwise just go straight to ground on Macintosh 128k.
   assign tsg_oe3 = gnd;

   /* N.B. The reason why phase calibration is required in the
      Macintosh 128k/512k/Plus is because the PALs do not have a RESET
      pin.  It is the logic designer's discretion to implement one
      explicitly, of they could forgo it to allow for more I/O pins.
      Hence the motivation to use software phase correction
      instead.  */

   // Inverters and 16MHz clock buffer
   f04 u4d(n_sysclk, sysclk, n_snddma, snddma, a20, n_a20, gnd,
	   n_sndres, sndres, n_snd, snd, wr, n_wr, vcc);
   // Dual PWM disk drive counters
   ls161 u13e(n_sndres, c8mf, rdq12, rdq13, rdq14, rdq15, n_snd, gnd,
	      n_dmald, u12f_tc, , , , , snd, vcc);
   ls161 u12f(n_sndres, c8mf, rdq8, rdq9, rdq10, rdq11, n_snd, gnd,
	      n_dmald, n_sndres, , , , , u12f_tc, vcc);
   // Dual video shift registers
   ls166 u10f(vmsh, rdq8, rdq9, rdq10, rdq11, 1'b0, c16mf, gnd,
	      s5, rdq12, rdq13, rdq14, n_servid, rdq15, n_vshft, vcc);
   ls166 u11f(s5, rdq0, rdq1, rdq2, rdq3, 1'b0, c16mf, gnd,
	      s5, rdq4, rdq5, rdq6, vmsh, rdq7, n_vshft, vcc);
   // Dual RAM data bus transceivers
   ls245 u9e(ram_r_n_w_f, rdq0, rdq1, rdq2, rdq3, rdq4, rdq5, rdq6, rdq7,
	     gnd, d7, d6, d5, d4, d3, d2, d1, d0, n_245oe, vcc);
   ls245 u10e(ram_r_n_w_f, rdq8, rdq9, rdq10, rdq11, rdq12, rdq13, rdq14,
	      rdq15, gnd, d15, d14, d13, d12, d11, d10, d9, d8,
	      n_245oe, vcc);
   // RAM RA8/RA9 row/column video/CPU address multiplexer
   f253 u10g(snddma, s1, va9, s5, a9, a17, ra8, gnd,
	     ra9, a20, a19, s5, s5, c2m, 1'b0, vcc);
   // Dual video address counters
   ls393 u1f(vclk, resnyb, va1, va2, va3, va4, gnd,
	     va8, va7, va6, va5, reslin, resnyb, vcc);
   ls393 u1g(va8, reslin, va9, va10, va11, va12, gnd,
	     , , va14, va13, reslin, va12, vcc);
   // RAM row/column video/CPU address multiplexers
   f257 u2f(c2m, s5, va6, ra0, n_snd, va7, ra1, gnd,
	    ra3/*???*/, va9, n_sndpg2, ra2, va8, n_sndpg2, n_snddma, vcc);
   f257 u2g(c2m, s5, va10, ra4, n_sndpg2, va11, ra5, gnd,
	    ra7, va13, s5, ra6, va12, s5, n_snddma, vcc);
   f253 u3f(snddma, s1, va3, va11, a3, a11, ra2, gnd,
	    ra3, a12, a4, va12, va4, c2m, snddma, vcc);
   f253 u3g(snddma, s1, va5, va13, a5, a13, ra4, gnd,
	    ra5, a14, a6, va14, va6, c2m, snddma, vcc);
   f253 u4f(snddma, s1, va1, s5, a1, a9, ra0, gnd,
	    ra1, a10, a2, va10, va2, c2m, snddma, vcc);
   f253 u4g(snddma, s1, va7, n_vidpg2, a7, a15, ra6, gnd,
	    ra7, a16, a8, s5, va8, c2m, snddma, vcc);

   tsm pal0(simclk, n_res, sysclk, sysclk, pclk, s1, n_ramen, n_romen, n_as, n_uds, n_lds,
	    gnd, tsm_oe1, casl, cash, ras, vclk, p0q2, p0q1, s0, n_dtack, vcc);
   lag pal1(simclk, n_res, sysclk, p2io1, l28, va4, p0q2, vclk, va3, va2, va1,
	    gnd, lag_oe2, n_vshft, n_vsync, n_hsync, s1, viapb6,
	    n_snddma, reslin,
	    resnyb, vcc);
   bmu1 pal2(simclk, n_res, va9, va8, va7, l15, va14, ovlay, a23, a22, a21, gnd,
	     n_as, n_csiwm, n_sccrd, n_cescc, n_vpa, n_romen, n_ramen, p2io1, l28, vcc);
   bmu0 pal3(simclk, n_res, sysclk, n_ramen, n_romen, va10, va11, va12, va13, va14,
	     r_n_w, gnd, bmu0_oe1, n_245oe, we, ava14, l15, vid, ava13,
	     n_servid, n_dtack, vcc);
   tsg pal4(simclk, n_res,
	    sysclk, n_vpa, a19, vclk, p0q1, e, keyclk, n_intscc,
	    n_intvia, gnd, tsg_oe3, d0, q6, clkscc, q4, q3, viacb1,
	    pclk, n_ipl0, vcc);

   // TODO FIXME: ASG not implemented.
   // asg u11e(c16mf, rdq0, rdq1, rdq2, rdq3, rdq4, rdq5, n_dma, vclk, gnd,
   // 	    tsen2, n_dmald, pwm, , , , , , , vcc);
endmodule

`endif // not MAC128PAL_V
