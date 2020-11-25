/* Implementation of standard logic integrated circuits in Verilog to
   facilitate board-level simulations of glue logic.  DIP pinout.

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

`ifndef STDLOGIC_V
`define STDLOGIC_V

`include "common.vh"

// F00: Quad NAND gates.
module f00(s1a, s1b, s1y, s2a, s2b, s2y, gnd,
	   s3y, s3b, s3a, s4y, s4b, s4a, vcc);
   input wire s1a, s1b;
   output wire s1y;
   input wire s2a, s2b;
   output wire s2y;
   `power wire gnd;
   output wire s3y;
   input wire s3b, s3a;
   output wire s4y;
   input wire s4b, s4a;
   `power wire vcc;

   assign s1y = ~(s1a & s1b);
   assign s2y = ~(s2a & s2b);
   assign s3y = ~(s3a & s3b);
   assign s4y = ~(s4a & s4b);
endmodule

// F02: Quad NOR gates.
module f02(s1y, s1a, s1b, s2y, s2a, s2b, gnd,
	   s3a, s3b, s3y, s4a, s4b, s4y, vcc);
   output wire s1y;
   input wire s1a, s1b;
   output wire s2y;
   input wire s2a, s2b;
   `power wire gnd;
   input wire s3a, s3b;
   output wire s3y;
   input wire s4a, s4b;
   output wire s4y;
   `power wire vcc;

   assign s1y = ~(s1a | s1b);
   assign s2y = ~(s2a | s2b);
   assign s3y = ~(s3a | s3b);
   assign s4y = ~(s4a | s4b);
endmodule

// F04: Hex inverters.
module f04(a0, q0, a1, q1, a2, q2, gnd, q5, a5, q4, a4, q3, a3, vcc);
   input wire  a0;
   output wire q0;
   input wire  a1;
   output wire q1;
   input wire  a2;
   output wire q2;
   `power wire gnd;
   output wire q5;
   input wire  a5;
   output wire q4;
   input wire  a4;
   output wire q3;
   input wire  a3;
   `power wire vcc;

   assign q0 = ~a0;
   assign q1 = ~a1;
   assign q2 = ~a2;
   assign q3 = ~a3;
   assign q4 = ~a4;
   assign q5 = ~a5;
endmodule

// F08: Quad AND gates.
module f08(s1a, s1b, s1y, s2a, s2b, s2y, gnd,
	   s3y, s3a, s3b, s4y, s4a, s4b, vcc);
   input wire s1a, s1b;
   output wire s1y;
   input wire s2a, s2b;
   output wire s2y;
   `power wire gnd;
   output wire s3y;
   input wire s3a, s3b;
   output wire s4y;
   input wire s4a, s4b;
   `power wire vcc;

   assign s1y = s1a & s1b;
   assign s2y = s2a & s2b;
   assign s3y = s3a & s3b;
   assign s4y = s4a & s4b;
endmodule

// F32: Quad OR gates.
module f32(s1a, s1b, s1y, s2a, s2b, s2y, gnd,
	   s3y, s3a, s3b, s4y, s4a, s4b, vcc);
   input wire s1a, s1b;
   output wire s1y;
   input wire s2a, s2b;
   output wire s2y;
   `power wire gnd;
   output wire s3y;
   input wire s3a, s3b;
   output wire s4y;
   input wire s4a, s4b;
   `power wire vcc;

   assign s1y = s1a | s1b;
   assign s2y = s2a | s2b;
   assign s3y = s3a | s3b;
   assign s4y = s4a | s4b;
endmodule

// LS161: 4-bit binary counter.
// Used to generate sequential video and sound RAM addresses.
module ls161(n_clr, clk, a, b, c, d, enp, gnd,
	     n_load, ent, q_d, q_c, q_b, q_a, rco, vcc);
   input wire n_clr, clk, a, b, c, d, enp;
   `power wire gnd;
   input wire n_load, ent;
   output wire q_d, q_c, q_b, q_a;
   output wire rco;
   `power wire vcc;

   wire [3:0] loadvec = { d, c, b, a };
   reg [3:0] outvec;

   assign rco = (outvec == 4'hf);
   assign { q_d, q_c, q_b, q_a } = outvec;

   // N.B. As soon as the rising edge of the clock is detected under
   // the proper conditions, we propagate the incremented value to the
   // output pins.  We do not wait until the next rising edge of the
   // clock.
   always @(posedge clk) begin
      if (~n_clr) outvec <= 0;
      else if (~n_load) outvec <= loadvec;
      else if (enp & ent)
	outvec <= outvec + 1;
      // else Nothing to be done.
   end
endmodule

// LS165: 8-bit Parallel In, Serial Out shift register.  Very similar
// to LS166 but *Q_H instead of *CLR and different pinout.
module ls165(sh_n_ld, clk, e, f, g, h, n_q_h, gnd,
	     q_h, ser, a, b, c, d, clk_inh, vcc);
   input wire sh_n_ld, clk, e, f, g, h;
   output wire n_q_h;
   `power wire gnd;
   output wire q_h;
   input wire ser, a, b, c, d, clk_inh;
   `power wire vcc;

   wire n_int_clk = ~(clk_inh | clk);
   reg [7:0] int_reg;

   assign q_h = int_reg[7];
   assign n_q_h = ~q_h;

   // N.B. As soon as the falling edge of the clock is detected under
   // the proper conditions, we propagate the shifted value to the
   // output pins.  We do not wait until the next falling edge of the
   // clock.
   always @(negedge n_int_clk) begin
      if (sh_n_ld)
	int_reg <= { int_reg[6:0], ser };
      else
	int_reg <= { h, g, f, e, d, c, b, a };
   end
endmodule

// LS166: 8-bit Parallel In, Serial Out shift register.
// Used to generate the TTL serial video signal.
module ls166(ser, a, b, c, d, clk_inh, clk, gnd,
	     n_clr, e, f, g, q_h, h, sh_n_ld, vcc);
   input wire ser, a, b, c, d, clk_inh, clk;
   `power wire gnd;
   input wire n_clr, e, f, g;
   output wire q_h;
   input wire h, sh_n_ld;
   `power wire vcc;

   wire n_int_clk = ~(clk_inh | clk);
   reg [7:0] int_reg;

   assign q_h = int_reg[7];

   always @(negedge n_clr)
     int_reg <= 0;

   // N.B. As soon as the falling edge of the clock is detected under
   // the proper conditions, we propagate the shifted value to the
   // output pins.  We do not wait until the next falling edge of the
   // clock.
   always @(negedge n_int_clk) begin
      if (n_clr) begin
	 if (sh_n_ld)
	   int_reg <= { int_reg[6:0], ser };
	 else
	   int_reg <= { h, g, f, e, d, c, b, a };
      end
   end
endmodule

// LS245: Octal bus transceivers.
// Used to control DRAM access from the CPU data bus.
module ls245(dir, a1, a2, a3, a4, a5, a6, a7, a8, gnd,
	     b8, b7, b6, b5, b4, b3, b2, b1, n_oe, vcc);
   input wire dir;
   inout wire a1, a2, a3, a4, a5, a6, a7, a8;
   `power wire gnd;
   inout wire b8, b7, b6, b5, b4, b3, b2, b1;
   input wire n_oe;
   `power wire vcc;

   // (~dir) => (ax <= bx), (dir) => (bx <= ax)

   // N.B. `assign` implements diode isolation to enforce a
   // directional output drive, so we can't assemble bi-directional
   // bit vectors for more compact code in that fashion.  `alias` from
   // System Verilog would make that possible, though.  Though we
   // could define a sub-module to use bit vectors, it turns out that
   // consumes just as many lines of code.  So we just go repetitive.

   assign a1 = (n_oe | dir) ? 8'bz : b1;
   assign a2 = (n_oe | dir) ? 8'bz : b2;
   assign a3 = (n_oe | dir) ? 8'bz : b3;
   assign a4 = (n_oe | dir) ? 8'bz : b4;
   assign a5 = (n_oe | dir) ? 8'bz : b5;
   assign a6 = (n_oe | dir) ? 8'bz : b6;
   assign a7 = (n_oe | dir) ? 8'bz : b7;
   assign a8 = (n_oe | dir) ? 8'bz : b8;

   assign b1 = (n_oe | ~dir) ? 8'bz : a1;
   assign b2 = (n_oe | ~dir) ? 8'bz : a2;
   assign b3 = (n_oe | ~dir) ? 8'bz : a3;
   assign b4 = (n_oe | ~dir) ? 8'bz : a4;
   assign b5 = (n_oe | ~dir) ? 8'bz : a5;
   assign b6 = (n_oe | ~dir) ? 8'bz : a6;
   assign b7 = (n_oe | ~dir) ? 8'bz : a7;
   assign b8 = (n_oe | ~dir) ? 8'bz : a8;
endmodule

// F138: 3-to-8 line decoder/demultiplexer, active low.
module f138(a0, a1, a2, n_e1, n_e2, e3, n_y7, gnd,
	    n_y6, n_y5, n_y4, n_y3, n_y2, n_y1, n_y0, vcc);
   input wire a0, a1, a2, n_e1, n_e2, e3;
   output wire n_y7;
   `power wire gnd;
   output wire n_y6, n_y5, n_y4, n_y3, n_y2, n_y1, n_y0;
   `power wire vcc;

   wire [2:0] va;
   wire en;

   assign va = { a2, a1, a0 };
   assign en = ~n_e1 & ~n_e2 & e3;

   assign n_y0 = ~(en & (va == 0));
   assign n_y1 = ~(en & (va == 1));
   assign n_y2 = ~(en & (va == 2));
   assign n_y3 = ~(en & (va == 3));
   assign n_y4 = ~(en & (va == 4));
   assign n_y5 = ~(en & (va == 5));
   assign n_y6 = ~(en & (va == 6));
   assign n_y7 = ~(en & (va == 7));
endmodule

// F238: 3-to-8 line decoder/demultiplexer, active high.
module f238(a0, a1, a2, n_e1, n_e2, e3, y7, gnd,
	    y6, y5, y4, y3, y2, y1, y0, vcc);
   input wire a0, a1, a2, n_e1, n_e2, e3;
   output wire y7;
   `power wire gnd;
   output wire y6, y5, y4, y3, y2, y1, y0;
   `power wire vcc;

   wire [2:0] va;
   wire en;

   assign va = { a2, a1, a0 };
   assign en = ~n_e1 & ~n_e2 & e3;

   assign y0 = en & (va == 0);
   assign y1 = en & (va == 1);
   assign y2 = en & (va == 2);
   assign y3 = en & (va == 3);
   assign y4 = en & (va == 4);
   assign y5 = en & (va == 5);
   assign y6 = en & (va == 6);
   assign y7 = en & (va == 7);
endmodule

// F253: Dual 4-to-1 multiplexer.
// Used for Macintosh Plus CPU/video/sound address selection.
module f253(n_1g, b, s1c3, s1c2, s1c1, s1c0, s1y, gnd,
	    s2y, s2c0, s2c1, s2c2, s2c3, a, n_2g, vcc);
   input wire n_1g, b, s1c3, s1c2, s1c1, s1c0;
   `output_wz wire s1y;
   `power wire gnd;
   `output_wz wire s2y;
   input wire s2c0, s2c1, s2c2, s2c3, a, n_2g;
   `power wire vcc;

   assign s1y = (n_1g) ? 'bz : sel1({ b, a });
   function sel1(input [1:0] selvec);
     case (selvec)
       0: sel1 = s1c0;
       1: sel1 = s1c1;
       2: sel1 = s1c2;
       3: sel1 = s1c3;
     endcase
   endfunction

   assign s2y = (n_2g) ? 'bz : sel2({ b, a });
   function sel2(input [1:0] selvec);
     case (selvec)
       0: sel2 = s2c0;
       1: sel2 = s2c1;
       2: sel2 = s2c2;
       3: sel2 = s2c3;
     endcase
   endfunction
endmodule

// F257: Quadruple 2-to-1 multiplexer. Used for RAS/CAS selection.
// LS257: Logically the same as F257.  (Only differs electrically.)
module f257(n_a_b, s1a, s1b, s1y, s2a, s2b, s2y, gnd,
	    s3y, s3b, s3a, s4y, s4b, s4a, n_oe, vcc);
   input wire n_a_b, s1a, s1b;
   `output_wz wire s1y;
   input wire s2a, s2b;
   `output_wz wire s2y;
   `power wire gnd;
   `output_wz wire s3y;
   input wire s3b, s3a;
   `output_wz wire s4y;
   input wire s4b, s4a, n_oe;
   `power wire vcc;

   assign s1y = (n_oe) ? 'bz : (~n_a_b) ? s1a : s1b;
   assign s2y = (n_oe) ? 'bz : (~n_a_b) ? s2a : s2b;
   assign s3y = (n_oe) ? 'bz : (~n_a_b) ? s3a : s3b;
   assign s4y = (n_oe) ? 'bz : (~n_a_b) ? s4a : s4b;
endmodule

// LS393: Dual 4-bit binary counter.
// Used to generate sequential video and sound RAM addresses.
module ls393(s1a, s1clr, s1q_a, s1q_b, s1q_c, s1q_d, gnd,
	     s2q_d, s2q_c, s2q_b, s2q_a, s2clr, s2a, vcc);
   input wire s1a, s1clr;
   output wire s1q_a, s1q_b, s1q_c, s1q_d;
   `power wire gnd;
   output wire s2q_d, s2q_c, s2q_b, s2q_a;
   input wire s2clr, s2a;
   `power wire vcc;

   reg [3:0] s1reg;
   reg [3:0] s2reg;

   assign { s1q_d, s1q_c, s1q_b, s1q_a } = s1reg;
   assign { s2q_d, s2q_c, s2q_b, s2q_a } = s2reg;

   always @(posedge s1clr)
      s1reg <= 0;
   always @(posedge s1a)
      s1reg <= s1reg + 1;
   always @(posedge s2clr)
      s2reg <= 0;
   always @(posedge s2a)
      s2reg <= s2reg + 1;

endmodule

// LS595: 8-bit serial input, parallel output shift register, with
// output latch.
module ls595(q_b, q_c, q_d, q_e, q_f, q_g, q_h, gnd,
	     n_q_h, n_srclr, srclk, rclk, n_oe, ser, vcc);
   output wire q_b, q_c, q_d, q_e, q_f, q_g, q_h;
   `power wire gnd;
   output wire n_q_h;
   input wire n_srclr, srclk, rclk, n_oe, ser;
   output wire q_a;
   `power wire vcc;

   reg [7:0] int_reg;
   reg [7:0] out_reg;

   assign { q_h, q_g, q_f, q_e, q_d, q_c, q_b, q_a }
     = (n_oe) ? 8'bz : int_reg;
   assign n_q_h = q_h;

   always @(negedge n_srclr) begin
      int_reg <= 0;
   end

   always @(posedge srclk) begin
      int_reg = { int_reg[7:1], ser };
   end

   // N.B. As soon as the rising edge of the clock is detected under
   // the proper conditions, we propagate the shifted value to the
   // output pins.  We do not wait until the next rising edge of the
   // clock.
   always @(posedge rclk) begin
      out_reg <= int_reg;
   end
endmodule

`endif // not STDLOGIC_V
