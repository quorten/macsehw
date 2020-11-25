/* Simulate asynchronous DRAM using Verilog SRAM constructs.

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

`ifndef DRAM_V
`define DRAM_V

// NOTE: The reset and clock inputs are solely for simulation
// purposes, namely for implementing DRAM row expiry.  WARNING: Row
// expiry will make simulation slow!
// `define ROW_EXPIRY

/* Important!  Restrictions on real DRAM that are currently not
   simulated:
 
   * Minimum hold times on *RAS and *CAS

   * Maximum hold times, though maximum hold time is somewhat
     implemented by virtue of row expiry.

   * Timing between asserting *RAS and *CAS.

   * DRAM initialization pulses before use
*/

// 64kbyte DRAM SIMM
module dram64kbyte(n_res, clk,
		   n_we, n_ras, n_cas,
		   ra, rdq);
   parameter RASBITS = 8;
   parameter ROWSIZE = 2**RASBITS;
   parameter WORDBITS = 8;

   // Used to replicate hardware constructs that simulate DRAM expiry.
   integer i, j;

   input wire n_res, clk;
   input wire n_we, n_ras, n_cas;
   input wire [RASBITS-1:0] ra;
   inout wire [WORDBITS-1:0] rdq;

   reg n_we_l; // Write-enable latched value
   reg [RASBITS-1:0] rowaddr, coladdr;

   reg [WORDBITS-1:0] rows[0:ROWSIZE-1][0:ROWSIZE-1];
`ifdef ROW_EXPIRY
   reg [15:0] rowexpire[0:ROWSIZE-1];
`endif

   assign rdq = (~n_ras & ~n_cas) ? rows[rowaddr][ra] : 'bz;

   always @(negedge n_res) begin
      // Initialize essential internal state to some sane values.
   end

   always @(negedge n_ras) begin
      rowaddr <= ra;
   end

   always @(negedge n_cas) begin
      coladdr <= ra;
      n_we_l <= n_we;
   end

   always @(posedge n_cas) begin
      if (~n_we_l)
	rows[rowaddr][coladdr] <= rdq;
   end

`ifdef ROW_EXPIRY
   always @(posedge n_ras) begin
      rowexpire[rowaddr] <= 65535;
   end

   always @(posedge clk) begin
      for (i = 0; i <= ROWSIZE-1; i = i + 1) begin
	 rowexpire[i] <= rowexpire[i] - 1;
	 if (rowexpire[i] == 0) begin
	    for (j = 0; j <= ROWSIZE-1; j = j + 1)
	      rows[i][j] <= 0;
	 end
      end
   end
`endif // ROW_EXPIRY
endmodule

// 256kbyte DRAM SIMM
module dram256kbyte(n_res, clk,
		      n_we, n_ras, n_cas,
		      ra, rdq);
   input wire n_res, clk;
   input wire n_we, n_ras, n_cas;
   input wire [8:0] ra;
   inout wire [7:0] rdq;

   dram64kbyte #(9, 2**9)
     u0(n_res, clk, n_we, n_ras, n_cas, ra, rdq);
endmodule

// 1Mbyte DRAM SIMM
module dram1mbyte(n_res, clk,
		      n_we, n_ras, n_cas,
		      ra, rdq);
   input wire n_res, clk;
   input wire n_we, n_ras, n_cas;
   input wire [9:0] ra;
   inout wire [7:0] rdq;

   dram64kbyte #(10, 2**10)
     u0(n_res, clk, n_we, n_ras, n_cas, ra, rdq);
endmodule

`endif // not DRAM_V
