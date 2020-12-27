`timescale 1ns/100ps

`include "mac128pal.v"

`include "test_stdlogic.v"

module test_palcl();
   wire vcc, gnd;
   reg n_res;
   reg clock;
   reg simclk;

   wire sysclk, pclk, p0q1, clkscc, p0q2, vclk, q3, q4;
   reg e, keyclk;

   reg [23:0] a;
   reg 	n_as, n_uds, n_lds;
   wire n_dtack;
   reg 	r_n_w;
   wire [15:0] d;

   wire casl, cash, ras, we;
   wire [9:0] ra;
   wire [15:0] rdq;
   reg 	n_intscc, n_intvia;
   wire n_ipl0;
   wire n_ramen, n_romen, n_csiwm, n_sccrd, n_cescc, n_vpa;
   wire viapb6;
   reg 	ovlay;
   wire viacb1;
   reg 	n_sndpg2, n_vidpg2;
   wire n_vsync, n_hsync, vid;

   assign vcc = 1;
   assign gnd = 0;

   palcl u0_palcl(simclk, vcc, gnd, n_res, clock,
		  sysclk, pclk, p0q1, clkscc, p0q2, vclk, q3, q4,
		  e, keyclk,
		  a[23], a[22], a[21], a[20], a[19], a[18], a[17], a[16],
		  a[15], a[14], a[13], a[12], a[11], a[10], a[9],
		  a[8], a[7], a[6], a[5], a[4], a[3], a[2], a[1],
		  n_as, n_uds, n_lds, n_dtack, r_n_w,
		  d[0], d[1], d[2], d[3], d[4], d[5], d[6], d[7],
		  d[8], d[9], d[10], d[11], d[12], d[13], d[14], d[15],
		  casl, cash, ras, we,
		  ra[0], ra[1], ra[2], ra[3], ra[4], ra[5], ra[6], ra[7],
		  ra[8], ra[9],
		  rdq[0], rdq[1], rdq[2], rdq[3], rdq[4], rdq[5], rdq[6],
		  rdq[7], rdq[8], rdq[9], rdq[10], rdq[11], rdq[12], rdq[13],
		  rdq[14], rdq[15],
		  n_intscc, n_intvia, n_ipl0,
		  n_ramen, n_romen, n_csiwm, n_sccrd, n_cescc, n_vpa,
		  viapb6, ovlay, viacb1, n_sndpg2, n_vidpg2,
		  n_vsync, n_hsync, vid);

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
      e = 0;
      keyclk = 0;
   end

   // 64 unit clock cycle (~16MHz).
   always
     #32 clock = ~clock;

   // ~1MHz 6800 E clock
   always begin
      #768 e = 1; // 6 CPU clocks low
      #512 e = 0; // 4 CPU clocks high
   end

   // Sub-cycle simulator clock triggers as fast as possible.

   // N.B.: This is now disabled as it has been vetted that Verilog is
   // designed to simulate self-referential combinatorial logic
   // equations just fine.  Disabling this helps speed up the
   // simulation.

   // always
   //   #1 simclk = ~simclk;

   // Initialize all other control inputs.
   initial begin
      a <= 0;
      n_as <= 1; n_uds <= 1; n_lds <= 1; r_n_w <= 1;
      n_intscc <= 1; n_intvia <= 1; ovlay <= 1;
      n_sndpg2 <= 1; n_vidpg2 <= 1;
   end
endmodule

module test_mac128pal();
   // Instantiate individual test modules.
   test_ls161 tu0_ls161();
   test_ls245 tu1_ls245();
   test_palcl tu2_palcl();

   // Perform the remainder of global configuration here.

   // Set simulation time limit.
   initial begin
      #1920000 $finish;
      // PLEASE NOTE: We must simulate LOTS of cycles in order to see
      // what the oscilloscope trace for one video frame looks like.
      // #30720000 $finish;
   end

   // We can use `$display()` for printf-style messages and implement
   // our own automated test suite that way if we wish.
   initial begin
      $display("Example message: Start of simulation.  ",
	       "(time == %1.0t)", $time);
   end

   // Log to a VCD (Variable Change Dump) file.
   initial begin
      // $dumpfile("test_mac128pal.vcd");
      // Use LXT instead since it is more efficient.
      $dumpfile("test_mac128pal.lxt");
      $dumpvars;
   end
endmodule
