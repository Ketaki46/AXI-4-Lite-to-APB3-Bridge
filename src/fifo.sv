`timescale 1ns / 1ps

module fifo #(parameter DSIZE = 32,
              parameter ASIZE = 5)
             (output reg [DSIZE-1:0] rdata,
              output reg wfull,              // write full flag
              output reg rempty,             // read empty flag
              input [DSIZE-1:0] wdata,
              input winc, wclk, wrst_n,
              input rinc, rclk, rrst_n);

  wire [ASIZE-1:0] waddr, raddr;
  reg [ASIZE:0] wptr, rptr;
  reg [ASIZE:0] wq2_rptr, wq1_rptr;
  reg [ASIZE:0] rq2_wptr, rq1_wptr;
  
  wire wclken, rclken;
  wire [ASIZE:0] rbin_next;         // read next addr ptr binary
  reg [ASIZE:0] rbin;               // read addr ptr binary
  wire [ASIZE:0] rgray_next;
  
  reg [ASIZE:0] wbin;
  wire [ASIZE:0] wgray_next;
  wire [ASIZE:0] wbin_next;
  
  wire rempty_val;
  localparam DEPTH = 1<<ASIZE;
  reg [DSIZE-1:0] mem [0:DEPTH-1] = {default: 0};
  wire wfull_val;
  
  
  
  // Write clock enable
  assign wclken = winc & ~wfull;
  // Read clock enable
  assign rclken = rinc & ~rempty;
  
  // Read pointer logic
  always @(posedge rclk or negedge rrst_n) begin
    if (!rrst_n)
      {rbin, rptr} <= 0;
    else begin
      rbin <= rbin_next;
      rptr <= rgray_next;
    end
  end
  assign raddr = rbin[ASIZE-1:0];
  assign rbin_next = rbin + (rinc & ~rempty); // Implicit increment assign rbin_next = rbin + (rinc & ~rempty ? 1 : 0);
  assign rgray_next = (rbin_next>>1) ^ rbin_next;
  
  // Empty flag logic
 
  assign rempty_val = (rgray_next == rq2_wptr);
  always @(posedge rclk or negedge rrst_n) begin
    if (!rrst_n)
      rempty <= 1'b1;
    else
    
       rempty <= rempty_val;
  end
  
  // Write pointer logic
  always @(posedge wclk or negedge wrst_n) begin
    if (!wrst_n)
      {wbin, wptr} <= 0;
    else begin
      wbin <= wbin_next;
      wptr <= wgray_next;
    end
  end
  assign waddr = wbin[ASIZE-1:0];
  assign wbin_next = wbin + (winc & ~wfull);
  assign wgray_next = (wbin_next>>1) ^ wbin_next;
  
  // Full flag logic
  assign wfull_val = (wgray_next == {~wq2_rptr[ASIZE:ASIZE-1], wq2_rptr[ASIZE-2:0]});
  always @(posedge wclk or negedge wrst_n) begin
    if (!wrst_n)
      wfull <= 1'b0;
    else
      wfull <= wfull_val;
  end
  
  // Cross-clock synchronization (write to read)
  always @(posedge wclk or negedge wrst_n) begin
    if (!wrst_n)
      {wq2_rptr, wq1_rptr} <= 0;
    else
      {wq2_rptr, wq1_rptr} <= {wq1_rptr, rptr};
  end
  
  // Cross-clock synchronization (read to write)
  always @(posedge rclk or negedge rrst_n) begin
    if (!rrst_n)
      {rq2_wptr, rq1_wptr} <= 0;
    else
      {rq2_wptr, rq1_wptr} <= {rq1_wptr, wptr};
  end
  
  // Memory write
  always @(posedge wclk)
    if (wclken && !wfull)
      mem[waddr] <= wdata;
  
  // Memory read with default hold
  always @(posedge rclk)
    if (rclken && !rempty)
      rdata <= mem[raddr]; // Non-blocking assignment
    else
      rdata <= rdata; // Hold previous value
  
//  // Debug statements
//  always @(posedge rclk)
//    if (rinc) $display("Time=%0t rbin=%b rgray_next=%b rq2_wptr=%b rempty=%b rdata=%h", $time, rbin, rgray_next, rq2_wptr, rempty, rdata);
//  always @(posedge wclk)
//    if (winc) $display("Time=%0t wbin=%b wgray_next=%b wq2_rptr=%b wfull=%b wdata=%h", $time, wbin, wgray_next, wq2_rptr, wfull, wdata);

endmodule
