`timescale 1ns/100ps

`include "mac128pal.v"

`include "test_stdlogic.v"

module test_mac128pal();
   // Instantiate individual test modules.
   test_ls161 tu0();
   test_ls245 tu1();   

   // Perform the remainder of global configuration here.

   // Set simulation time limit.
   initial begin
      #480 $finish;
   end

   // We can use `$display()` for printf-style messages and implement
   // our own automated test suite that way if we wish.
   initial begin
      $display("Example message: Start of simulation.  ",
	       "(time == %1.0t)", $time);
   end

   // Log to a VCD (Variable Change Dump) file.
   initial begin
      $dumpfile("test_mac128pal.vcd");
      $dumpvars;
   end
endmodule
