`ifndef COMMON_VH
`define COMMON_VH

// Special type indicator for simclk: it will not be present in
// physical builds.
`define virtwire wire
// Simulate an output wire by using multi-cycle registered logic.
`define simwire reg
// Tristate output (output With high-impedance (Z))
`define output_wz inout
// To preserve pin numbering at the I/O connections, power wires can
// be implemented as inputs: constant value 1 for Vcc, 0 for GND.
`define power input

`endif // not COMMON_VH
