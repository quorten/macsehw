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
module tsm(simclk, clk, sysclk, pclk, s1, ramen, romen, as, uds, lds, gnd,
	   oe1, casl, cash, ras, vclk, q2, q1, s0, dtack, vcc);
   input `virtwire simclk;
   input wire clk;
   input wire sysclk, pclk, s1, ramen, romen, as, uds, lds;
   `power wire gnd;
   input wire oe1;
   output `simwire casl, cash;
   output reg ras, vclk, q2, q1;
   output `simwire s0, dtack;
   `power wire vcc;

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
      s0 <= ~(~ras & ~sysclk // 0 for `cas` and 1 for `ras` (estamos contando com o atraso da PAL)
	      | ~ras & ~s0);
      dtack <= ~(~romen // se a ROM for de 250 nS ou SCC ou IWM
		 | ~ras & ~ramen & ~s1 // garante que vai ser reconhecido na descida de `pclk` no estado `s5`
		 | ~as & ~dtack & ramen // espera `as` subir para desativar
		 | ~as & ~dtack & ~s1); // mas evite ciclas de video (WE)
   end

   // Simulate registered logic.
   always @(posedge clk) begin
      ras <= ~(~pclk & q1 & s1 // video cycle
	       | ~pclk & q1 & ~ramen & dtack // processor cycle
	       | pclk & ~ras); // any other (?) (segura mais um ciclo) cycle
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
module lag(simclk, sysclk, p2io1, l28, va4, p0q2, vclk, va3, va2, va1,
	   gnd, oe2, vshft, vsync, hsync, s1, viapb6, snddma,
	   reslin, resnyb, vcc);
   input `virtwire simclk;
   input wire sysclk;
   input wire p2io1, l28, va4, p0q2, vclk, va3, va2, va1;
   `power wire gnd;
   input wire oe2;
   output reg vshft, vsync, hsync, s1, viapb6, snddma, reslin, resnyb;
   `power wire vcc;

   // Simulate combinatorial logic sub-cycles.
   always @(posedge simclk) begin
   end

   // Simulate registered logic.
   always @(posedge sysclk) begin
      vshft <= ~(s1 & ~vclk & snddma); // um pulso depois da descida de `vclk`
      vsync <= ~(reslin
		 | ~vsync & ~l28);
      hsync  <= ~(viapb6 & va4 & ~va3 & ~va2 & va1 // comec,a em29 (VA5)
		  | /*~ ???*/resnyb
		  | ~hsync & viapb6); // termina em 0F
      s1 <= ~(~p0q2 // 0 for processor and 1 for video
	      | ~vclk
	      | ~vsync & hsync
	      | ~vsync & viapb6 // no vertical retrace s'o temos ciclos de som
	      | ~viapb6 & hsync & ~va4 & ~va3 & ~va2
	      | ~viapb6 & ~hsync & (~va4 | va4 & ~va3 & ~va2 |
				    va4 & ~va3 & va2 & ~va1));
      viapb6 <= ~(~hsync & resnyb // 1 indicates horizontal retrace (pseudo VA6)
		  | va1 & ~viapb6
		  | va2 & ~viapb6
		  | ~hsync & ~viapb6
		  | resnyb & ~viapb6
		  | vshft & ~viapb6);
      snddma <= ~(viapb6 & va4 & ~va3 & va2 & va1 & p0q2 & vclk & ~hsync // 0 nesta sa'ida
		  | ~snddma & vclk); // ... indicates sound cycle
      reslin <= ~(0); // ??? tentamos gerar linha 370
      resnyb <= ~(vclk // incrementa VA5:VA14 em 0F e 2B
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

// 32 ciclas atiuas par linha - UA6..UA1 = 0 to 1F
// 1 ciclos de som/pwm                   = 2B
// 11 ciclos de retrac,o                 = 20 to 2A

// 342 linhas ativas    - VA6..VA14 = 010011100 to 111110001
// 28 linhas de retrac,o            = 010000000 to 010011011

// PAL2-16L8: Bus Management Unit 1
module bmu1(simclk, va9, va8, va7, l15, va14, ovlay, a23, a22, a21, gnd,
	    as, csiwm, rd, cescc, vpa, romen, ramen, io1, l28, vcc);
   input `virtwire simclk;
   input wire va9, va8, va7, l15, va14, ovlay, a23, a22, a21;
   `power wire gnd;
   input wire as;
   output `simwire csiwm, rd, cescc, vpa, romen, ramen, io1, l28;
   `power wire vcc;

   // Simulate combinatorial logic sub-cycles.
   always @(posedge simclk) begin
      csiwm <= ~(a23 & a22 & ~a21 & ~as); // DFE1FF
      rd <= ~(a23 & ~a22 & ~a21 & ~as); // 9FFFF8
      cescc <= ~(a23 & ~a22 & ~as); // 9FFFF8(R) or BFFFF9(W)
      vpa <= ~(a23 & a22 & a21 & ~as); // acima de E00000 'e s'incrano
      romen <= ~(~a23 & a22 & ~a21 & ~as // 400000
		 | ~a23 & ~a22 & ~a21 & ~as & ovlay // (and 000000 with `ovlay`)
		 | a23 & ~a22 & ~as
		 | a23 & ~a21 & ~as); // para gerar DTACK (n~ao acessa ROM: A20)
      ramen <= ~(~a23 & ~a22 & ~a21 & ~as & ~ovlay // 000000
		 | ~a23 & a22 & a21 & ~as & ovlay); // (600000 with `ovlay`)
      io1 <= ~(0); // ???
      l28 <= ~(~l15 & ~va9 & ~va8 & va7 // chegamos a 370 ou n~ao passamos da limha 28
	       | ~l28 & ~va9
	       | ~l28 & ~va8
	       | ~l28 & ~va7);
   end
endmodule

// PAL3-16R4: Bus Management Unit 0
module bmu0(simclk, sysclk, ramen, romen, va10, va11, va12, va13, va14, rw,
	    gnd, oe1, g244, we, ava14, l15, vid, ava13, servid, dtack, vcc);
   input `virtwire simclk;
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

   // Simulate combinatorial logic sub-cycles.
   always @(posedge simclk) begin
      g244 <= ~(~ramen & rw
		| ~g244 & ~ramen);
      we <= ~(~ramen & ~rw
	      | ~we & ~dtack); // o dtack 'e mais curto antes de ciclo de video
   end

   // Simulate registered logic.
   always @(posedge sysclk) begin
      ava14 <= ~(~va14 & ~va13); // + 1
      l15 <= ~(~va14 & ~va13 & ~va12 & ~va11 & ~va10 // n~ao passamos da linha 15
	       | va14 & ~va13 & va12 & va11 & va10); // passamos de 368
      vid <= ~(servid); // aqui estamos invertendo: blanking est'a em `vshft`
      ava13 <= ~(va13); // + 1
   end
endmodule

// PAL4-16R6: Timing Signal Generator
module tsg(simclk, sysclk, vpa, a19, vclk, p0q1, e, keyclk, intscc, intvia,
	   gnd, oe3, d0, q6, clkscc, q4, q3, viacb1, pclk, ipl0, vcc);
   input `virtwire simclk;
   input wire sysclk;
   input wire vpa, a19, vclk, p0q1, e, keyclk, intscc, intvia;
   `power wire gnd;
   input wire oe3;
   output `simwire d0;
   output reg q6, clkscc, q4, q3, viacb1, pclk;
   output `simwire ipl0;
   `power wire vcc;

   // Simulate combinatorial logic sub-cycles.
   always @(posedge simclk) begin
      ipl0 <= ~intscc | intvia; // CORRECTION
      // ipl0 <= ~(0); // ??? /M nanda
      d0 <= ~(~vpa & ~a19 & e); // F00000 amostra a fase como 0  /n e' + usado
   end

   // Simulate registered logic.
   always @(posedge sysclk) begin
      // TODO VERIFY: q6 missing?
      q6 <= ~(0);
      clkscc <= ~(clkscc & ~pclk & ~q4
		  | clkscc & ~pclk & ~q3
		  | clkscc & ~pclk & vclk
		  | ~clkscc & pclk
		  | ~clkscc & q4 & q3 & ~vclk); // a cada 32 ciclos n~ao vira
      viacb1 <= ~(0); // ??? /M nanda
      pclk <= ~(pclk); // divide SYSCLK por 2 (8MHz)
      q3 <= ~(~vclk); // `sysclk` / 16
      q4 <= ~(q4 & q3 & ~vclk // `sysclk` / 32
	      | ~q4 & ~q3                       // } J p/gerar CLKSCC
	      | ~q4 & vclk);
   end
endmodule

/* TODO: Now in order to fully implement the Macintosh's custom board
   capabilities, we must as a baseline have an implementation of some
   standard logic chips that are found on the Macintosh Main Logic
   Board.  This is where we implement the modules.  */
`include "stdlogic.v"

// Wire that PAL cluster together, along with supporting standard
// logic chip.  Here, we try to better indicate active high and active
// low because we also need to stick in a hex inverter chip.
module palcl();
   input `virtwire simclk;
   `power wire vcc;
   `power wire gnd;
   input wire n_res;
   input wire n_sysclk; // 16MHz

   // Clocks
   // 8,4,3.686,2,1,1,0.5 MHz
   output wire pclk, p0q1, clkscc, p0q2, vclk, q3, q4;
   input wire e; // 6800 synchronous I/O "E" clock, ~1MHz
   input wire keyclk;

   // TODO: Also implement dual video address counter ICs as part of
   // the PAL cluster.
   // Video address signals, comes from video counter IC
   input wire va14, va13, va12, va11, va10, va9, va8, va7,
	      va4, va3, va2, va1;
   // Audio address signals?
   output wire ava14, ava13;

   // Video control signals
   output wire n_vshft, n_vsync, n_hsync, n_snddma, vid;
   input wire servid;

   // MC68000 CPU address signals
   input wire a23, a22, a21, a20, a19, a17, a9;
   input wire n_as, n_uds, n_lds;
   output wire n_dtack;
   input wire r_n_w;
   inout wire d0, d1, d2, d3, d4, d5, d6, d7,
	      d8, d9, d10, d11, d12, d13, d14, d15;

   // Chip enable signals
   output wire n_ramen, n_romen, n_csiwm, n_sccrd, n_cescc, n_vpa;

   // Interrupt signals
   input wire n_intscc, n_intvia;
   output wire n_ipl0;

   // VIA signals
   output wire viapb6; // horizontal blanking
   input wire ovlay; // Boot-time overlay
   output wire viacb1; // keyboard interrupt
   // wire d0; // Video timing phase sense signal

   // DRAM signals
   output wire casl, cash, ras, we;
   inout wire rdq0, rdq1, rdq2, rdq3, rdq4, rdq5, rdq6, rdq7,
	      rdq8, rdq9, rdq10, rdq11, rdq12, rdq13, rdq14, rdq15;

   // Address multiplexer signals?
   output wire s0, s1, l28, l15, g244;

   // PAL chip-select and unknown "IO" signals
   wire tsm_oe1, lag_oe2, bmu0_oe1, tsg_oe3;

   // Internal PAL cluster use only, supports video
   wire reslin, resnyb; // video counter controllers?
   wire p2io1, q6;

   // Wires to/from standard logic chips.
   wire sysclk, snddma, n_a20, n_sndres, sndres, n_snd, snd, wr, n_wr;
   wire n_245oe;

   // N.B.: *WR comes from IWM chip, WR goes to floppy drives.  *A20
   // goes to VIA.CS1.  *SNDDMA comes from the LAG.  *SYSCLK comes
   // from the 16MHz crystal oscillator.

   // *DMALD is generated by ASG.

   wire c8mf, c16mf, n_dmald, u12f_tc, ram_r_n_w_f;
   wire vmsh; // video mid-shift, connect two register chips together
   wire n_lermd; // ???
   wire n_ldps;
   wire s5;
   wire ra8, ra9;

   wire vid_n_a4; // ???

   // TODO FIXME!  We're not using assign correctly!  `assign` implies
   // diode isolation between separate nets.  We want to merge
   // multiple names together for the same net.

   // N.B. on PCB, use c8mf for high-frequency signal
   // filter/conditioning.
   assign c8mf = pclk;
   assign c16mf = sysclk;
   assign ram_r_n_w_f = we;

   /* N.B. The reason why phase calibration is required in the
      Macintosh is because the PALs do not have a RESET pin.  It is
      the logic designer's discretion to implement one explicitly, of
      they could forgo it to allow for more I/O pins.  Hence the
      motivation to use software phase correction instead.  */

   f04 u4d(n_sysclk, sysclk, n_snddma, snddma, a20, n_a20, gnd,
	   n_sndres, sndres, n_snd, snd, wr, n_wr, vcc);

   ls161 u13e(n_sndres, c8mf, rdq12, rdq13, rdq14, rdq15, n_snd, gnd,
	      n_dmald, u12f_tc, , , , , snd, vcc);
   ls161 u12f(n_sndres, c8mf, rdq8, rdq9, rdq10, rdq11, n_snd, gnd,
	      n_dmald, n_sndres, , , , , u12f_tc, vcc);
   ls166 u10f(vmsh, rdq8, rdq9, rdq10, rdq11, 1'b0, c16mf, gnd,
	      s5, rdq12, rdq13, rdq14, n_lermd, rdq15, n_ldps, vcc);
   ls166 u11f(s5, rdq0, rdq1, rdq2, rdq3, 1'b0, c16mf, gnd,
	      s5, rdq4, rdq5, rdq6, vmsh, rdq7, n_ldps, vcc);
   ls245 u9e(ram_r_n_w_f, rdq0, rdq1, rdq2, rdq3, rdq4, rdq5, rdq6, rdq7,
	     gnd, d7, d6, d5, d4, d3, d2, d1, d0, n_245oe, vcc);
   ls245 u10e(ram_r_n_w_f, rdq8, rdq9, rdq10, rdq11, rdq12, rdq13, rdq14,
	      rdq15, gnd, d15, d14, d13, d12, d11, d10, d9, d8,
	      n_245oe, vcc);
   f253 u10g(snddma, vid_n_a4, va7, s5, a9, a17, ra8, gnd,
	     ra9, a20, a19, s5, s5, p0q2/*c2m*/, 1'b0, vcc);

   // asg u11e(c16mf, rdq0, rdq1, rdq2, rdq3, rdq4, rdq5, n_dma, vclk, gnd,
   // 	    tsen2, n_dmald, pwm, , , , , , , vcc);

   tsm pal0(simclk, sysclk, sysclk, pclk, s1, n_ramen, n_romen, n_as, n_uds, n_lds,
	    gnd, tsm_oe1, casl, cash, ras, vclk, p0q2, p0q1, s0, n_dtack, vcc);
   lag pal1(simclk, sysclk, p2io1, l28, va4, p0q2, vclk, va3, va2, va1,
	    gnd, lag_oe2, n_vshft, n_vsync, n_hsync, s1, viapb6,
	    n_snddma, reslin,
	    resnyb, vcc);
   bmu1 pal2(simclk, va9, va8, va7, l15, va14, ovlay, a23, a22, a21, gnd,
	     n_as, n_csiwm, n_sccrd, n_cescc, n_vpa, n_romen, n_ramen, p2io1, l28, vcc);
   bmu0 pal3(simclk, sysclk, n_ramen, n_romen, va10, va11, va12, va13, va14,
	     r_n_w, gnd, bmu0_oe1, g244, we, ava14, l15, vid, ava13,
	     servid, n_dtack, vcc);
   tsg pal4(simclk, sysclk, n_vpa, a19, vclk, p0q1, e, keyclk, n_intscc,
	    n_intvia, gnd, tsg_oe3, d0, q6, clkscc, q4, q3, viacb1,
	    pclk, n_ipl0, vcc);
endmodule

`endif // not MAC128PAL_V
