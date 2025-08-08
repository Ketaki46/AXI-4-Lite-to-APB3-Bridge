// `include "uvm_macros.svh"
// import uvm_pkg::*;

// interface apb_interface (input bit clk, input bit reset);
  
//   logic        psel;
//   logic        penable;
//   logic        pwrite;
//   logic [31:0] paddr;
//   logic [31:0] pwdata;
//   logic [31:0] prdata;
//   logic        pready;
//   logic        pslverr;

//   // Monitor clocking block only (no driver needed)
//   clocking monitor_cb @(posedge clk);
//     input psel, penable, pwrite, paddr, pwdata;
//     input prdata, pready, pslverr;
//   endclocking

//   modport monitor(clocking monitor_cb);

// endinterface
