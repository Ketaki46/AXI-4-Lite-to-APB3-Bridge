`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company:
// Engineer:
//
// Create Date: 19/07/2025 07:37:40 PM
// Design Name:
// Module Name: tb_fifo
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

`include "fifo.v"
module tb_fifo;
  parameter DSIZE = 8;
  parameter ASIZE = 4;

  reg  [DSIZE-1:0] wdata;
  reg              winc, wclk, wrst_n;
  reg              rinc, rclk, rrst_n;
  wire [DSIZE-1:0] rdata;
  wire             wfull, rempty;

  // Instantiate the FIFO
  fifo #(DSIZE, ASIZE) tb0 (
    .rdata(rdata),
    .wfull(wfull),
    .rempty(rempty),
    .wdata(wdata),
    .winc(winc),
    .wclk(wclk),
    .wrst_n(wrst_n),
    .rinc(rinc),
    .rclk(rclk),
    .rrst_n(rrst_n)
  );

  // Clock generation
  initial begin
    wclk = 0;
    forever #5 wclk = ~wclk;  // 100 MHz write clock
  end

  initial begin
    rclk = 0;
    forever #7 rclk = ~rclk;  // 71.4 MHz read clock
  end

  // Test sequence
  initial begin
    // Initialize signals
    wrst_n = 1;
    rrst_n = 1;
    #100;
    wdata  = 0;
    winc   = 0;
    rinc   = 0;
    wrst_n = 0;
    rrst_n = 0;

    // Apply reset
    #100;
    wrst_n = 1;
    rrst_n = 1;

    // Write 1 to 5
    @(posedge wclk);
    repeat (5) begin
      if (!wfull) begin
        winc <= 1;
        wdata <= wdata + 1;
      end
      else
        winc <= 0;
      @(posedge wclk);
    end
   
    winc <= 0; // Stop writing

    // Wait a bit
    #50;
   
   
    // reading makes empty
    @(posedge rclk);
    repeat (6) begin
      if (!rempty) begin
        rinc <= 1;
      end else begin
        rinc <= 0;
      end
      @(posedge rclk);
    end
   
    rinc <= 0;//stop reading

   
    #100;
   
    wdata  = 0;
    //writing makes full [1 to 16]
      @(posedge wclk);
    repeat (30) begin
      if (!wfull) begin
        winc <= 1;
        wdata <= wdata + 1;
      end
      else
        winc <= 0;
      @(posedge wclk);
    end
   
    winc <= 0; // Stop writing

    // Wait a bit
    #50;
   
     // reading
    @(posedge rclk);
    repeat (25) begin
      if (!rempty) begin
        rinc <= 1;
      end else begin
        rinc <= 0;
      end
      @(posedge rclk);
    end
   
    rinc <= 0;//stop reading
   
    #100;
    $finish;
  end

  // Monitor outputs
  initial begin
  $dumpfile("file1.vcd");
  $dumpvars(0,fifo1_tb);
    $monitor($time, " wdata=%h winc=%b wfull=%b | rdata=%h rinc=%b rempty=%b",
             wdata, winc, wfull, rdata, rinc, rempty);
  end

endmodule
