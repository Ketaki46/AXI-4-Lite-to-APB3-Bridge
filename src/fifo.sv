`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 18.07.2025 11:38:51
// Design Name: 
// Module Name: fifo
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module fifo #(parameter DSIZE = 8,
 parameter ASIZE = 4)
  (output reg [DSIZE-1:0] rdata,
 output reg wfull,              // write full flag
 output reg rempty,             // read empty flag
 input [DSIZE-1:0] wdata,
 input winc, wclk, wrst_n,
 input rinc, rclk, rrst_n);
 

 wire [ASIZE-1:0] waddr, raddr;
 reg [ASIZE:0] wptr, rptr;
 reg [ASIZE:0] wq2_rptr, rq2_wptr;
  
 reg [ASIZE:0] wq1_rptr;
 wire rempty1;
 reg [ASIZE:0] rq1_wptr;
 wire wclken,rclken;
//  assign rempty = rempty1;
  
  wire [ASIZE:0] rbin_next;         // read next addr ptr binary
  reg [ASIZE:0] rbin;               // read addr ptr binary
  wire [ASIZE:0] rgray_next;
  
 reg [ASIZE:0] wbin;
 wire [ASIZE:0] wgray_next;
 wire [ASIZE:0] wbin_next;
  
 wire rempty_val;
  
    
  localparam DEPTH = 1<<ASIZE;
 reg [DSIZE-1:0] mem [0:DEPTH-1];
 

 wire wfull_val;
  
  
 //  rptr_empty 
  
 //-------------------
 // GRAYSTYLE2 pointer
 //-------------------
 
 // logic to increment read ptr and bin o gray (continouos)
 
 always @(posedge rclk or negedge rrst_n) begin
 if (!rrst_n) 
    {rbin, rptr} <= 0;
 else begin
    rbin <= rbin_next;    
    rptr <= rgray_next;
 end
end 
 
 
 // Memory read-address pointer (okay to use binary to address memory)
 assign raddr = rbin[ASIZE-1:0];
 assign rbin_next = rbin + (rinc & ~rempty);       // read ptr incremenating condition if not empty
 assign rgray_next = (rbin_next>>1) ^ rbin_next;   // convert rbin_next to gray_next. 
 
//---------------------------------------------------------------
 // FIFO empty when the next rptr == synchronized wptr or on reset
 //---------------------------------------------------------------

// empty condition check - rdptr == read clock write pointer 
// writing separate assign and <= for readability 
 assign rempty_val = (rgray_next == rq2_wptr);    // rq2_wptr = read clock write pointer
 
  always @(posedge rclk or negedge rrst_n) begin
 if (!rrst_n) 
    rempty <= 1'b1;
 else 
    rempty <= rempty_val;

  end


   

//  wptr_full

 // GRAYSTYLE2 pointer
 always @(posedge wclk or negedge wrst_n)begin
    if (!wrst_n)
        {wbin, wptr} <= 0;
 else begin 
    wbin <= wbin_next;
    wptr <= wgray_next;
 end 
end 


 // Memory write-address pointer (okay to use binary to address memory)
 assign waddr = wbin[ASIZE-1:0];
 assign wbin_next = wbin + (winc & ~wfull);
 assign wgray_next = (wbin_next>>1) ^ wbin_next;
 
// rollover condition - when rollover happens, gray 2 MSB bits becomes inverted of previous bits without rollover. Eg - for 4 bit gray sequence, 8 bits are true bits, then rollover happens then 
// first 2 MSB bits inverted, while last 2 (LSB bits) are same for next 8 bits. - total 16 bits.
assign wfull_val = (wgray_next=={~wq2_rptr[ASIZE:ASIZE-1],wq2_rptr[ASIZE-2:0]});


 always @(posedge wclk or negedge wrst_n) begin
 if (!wrst_n)
    wfull <= 1'b0;
 else 
    wfull <= wfull_val;
end
 
 
//  sync_r2w tb1 (.wq2_rptr(wq2_rptr), .rptr(rptr),
//  .wclk(wclk), .wrst_n(wrst_n));

 // 2 flop synch logic
  always @(posedge wclk or negedge wrst_n) begin
 if (!wrst_n)
    {wq2_rptr,wq1_rptr} <= 0;
 else 
    {wq2_rptr,wq1_rptr} <= {wq1_rptr,rptr};

end
  


  //  sync_w2r tb2 (.rq2_wptr(rq2_wptr), .wptr(wptr),
//  .rclk(rclk), .rrst_n(rrst_n));
  
 
 
 always @(posedge rclk or negedge rrst_n)
 if (!rrst_n)
    {rq2_wptr,rq1_wptr} <= 0;
 else 
    {rq2_wptr,rq1_wptr} <= {rq1_wptr,wptr};


  
 //  fifo_memory 

    assign wclken = winc & ~wfull;  // Write clock enable when write is valid and FIFO is not full
    assign rclken = rinc & ~rempty;



 always @(posedge rclk)
 if (rclken && !rempty) 
    rdata = mem[raddr];


 always @(posedge wclk)
 if (wclken && !wfull) 
    mem[waddr] <= wdata;


endmodule
