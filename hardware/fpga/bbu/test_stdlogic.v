`ifndef TEST_STDLOGIC_V
`define TEST_STDLOGIC_V

`include "stdlogic.v"

module test_ls161();
   wire vcc, gnd;
   reg n_res;
   reg clock;
   reg simclk;

   reg n_clr, n_load, enp, ent;
   reg [3:0] loadvec;
   wire [3:0] outvec;
   wire rco;

   assign vcc = 1;
   assign gnd = 0;

   ls161 u0_ls161(n_clr, clock,
		  loadvec[0], loadvec[1], loadvec[2], loadvec[3],
		  enp, gnd,
		  n_load, ent,
		  outvec[3], outvec[2], outvec[1], outvec[0],
		  rco, vcc);

   // Trigger RESET at beginning of simulation.  Make sure there is an
   // initial falling edge.
   initial begin
      n_res = 1;
      #2 n_res = 0;
      #18 n_res = 1;
   end

   // Initialize clock.
   initial begin
      clock = 0;
      simclk = 0;
   end

   // 10 unit clock cycle.
   always
     #5 clock = ~clock;

   // Sub-cycle simulator clock triggers as fast as possible.
   always
     #1 simclk = ~simclk;

   // Play with input values a bit.
   initial begin
      n_load = 1;
      n_clr = 1;
      loadvec = 4'hc;
      enp = 1;
      ent = 1;
      #2 n_clr = 0;
      #18 n_clr = 1;
      #222 n_load = 0;
      #18 n_load = 1;
      #40 enp = 0;
      #20 enp = 1;
      #40 ent = 0;
      #20 ent = 1;
   end
endmodule

module test_ls245();
   wire vcc, gnd;

   reg dir, n_oe, n_oe_a, n_oe_b;
   reg [7:0] drv_a, drv_b;
   wire [7:0] sa, sb; // sense_a, sense_b

   assign vcc = 1;
   assign gnd = 0;

   assign sa = (n_oe_a) ? 8'bz : drv_a;
   assign sb = (n_oe_b) ? 8'bz : drv_b;

   ls245 u0_ls245(dir, sa[0], sa[1], sa[2], sa[3], sa[4], sa[5],
		  sa[6], sa[7], gnd, sb[7], sb[6], sb[5], sb[4],
		  sb[3], sb[2], sb[1], sb[0], n_oe, vcc);

   // Play with input values a bit.
   initial begin
      dir = 0;
      n_oe = 1;
      n_oe_a = 1;
      n_oe_b = 1;
      drv_a = 0;
      drv_b = 0;
      #10 n_oe = 0;
      #10 n_oe_b = 0;
      #10 drv_b = 8'hc6;
      #10 drv_b = 8'h35;
      #10 n_oe_b = 1; n_oe_a = 0;
      #10 dir = 1;
      #10 drv_a = 8'h7f;
      #10 n_oe_a = 1; n_oe_b = 0; dir = 0;
      #10 n_oe_a = 0; n_oe_b = 1; dir = 1;
      #10 n_oe_b = 0; // Test a conflict condition.
      #10 dir = 0; n_oe_a = 1; // Release the conflict.
      #10 n_oe = 1; n_oe_a = 1; n_oe_b = 1;
   end
endmodule

`endif // not TEST_STDLOGIC_V
