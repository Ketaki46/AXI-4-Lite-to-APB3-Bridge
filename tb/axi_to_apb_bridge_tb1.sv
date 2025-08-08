
`timescale 1ns / 1ps

module axi_to_apb_bridge_tb1;

// Parameters
parameter DATA_WIDTH = 32;
parameter ADDRESS = 32;
parameter FIFO_ASIZE = 3;

// AXI4-Lite Signals
logic ACLK = 0;
logic ARESETN = 0;
logic PCLK = 0;
logic PRESETN = 0;
logic [ADDRESS-1:0] S_ARADDR;
logic S_ARVALID;
logic S_RREADY;
logic [ADDRESS-1:0] S_AWADDR;
logic S_AWVALID;
logic [DATA_WIDTH-1:0] S_WDATA;
logic [3:0] S_WSTRB;
logic S_WVALID;
logic S_BREADY;
logic S_ARREADY;
logic [DATA_WIDTH-1:0] S_RDATA;
logic [1:0] S_RRESP;
logic S_RVALID;
logic S_AWREADY;
logic S_WREADY;
logic [1:0] S_BRESP;
logic S_BVALID;

// APB3 Signals
logic PSEL;
logic PENABLE;
logic PWRITE;
logic [ADDRESS-1:0] PADDR;
logic [DATA_WIDTH-1:0] PWDATA;
logic [DATA_WIDTH-1:0] PRDATA;
logic PREADY;
logic PSLVERR;

// DUT Instance
axi_to_apb_bridge #(
    .DATA_WIDTH(DATA_WIDTH),
    .ADDRESS(ADDRESS),
    .FIFO_ASIZE(FIFO_ASIZE)
) dut (
    .ACLK(ACLK), .ARESETN(ARESETN), .PCLK(PCLK), .PRESETN(PRESETN),
    .S_ARADDR(S_ARADDR), .S_ARVALID(S_ARVALID), .S_ARREADY(S_ARREADY),
    .S_RREADY(S_RREADY), .S_RDATA(S_RDATA), .S_RRESP(S_RRESP), .S_RVALID(S_RVALID),
    .S_AWADDR(S_AWADDR), .S_AWVALID(S_AWVALID), .S_AWREADY(S_AWREADY),
    .S_WDATA(S_WDATA), .S_WSTRB(S_WSTRB), .S_WVALID(S_WVALID), .S_WREADY(S_WREADY),
    .S_BREADY(S_BREADY), .S_BRESP(S_BRESP), .S_BVALID(S_BVALID),
    .PSEL(PSEL), .PENABLE(PENABLE), .PWRITE(PWRITE), .PADDR(PADDR),
    .PWDATA(PWDATA), .PRDATA(PRDATA), .PREADY(PREADY), .PSLVERR(PSLVERR)
);

// APB Slave Model (Simple Memory)
reg [DATA_WIDTH-1:0] apb_memory [0:31];
initial begin
    for (int i = 0; i < 32; i = i + 1) begin
        apb_memory[i] = i*i; // Initialize for testing
    end
end

always @(posedge PCLK or negedge PRESETN) begin
    if (!PRESETN) begin
        PREADY <= 0;
        PSLVERR <= 0;
        PRDATA <= 32'b0;
    end else if (PSEL && PENABLE && !PWRITE) begin
        PREADY <= 1;
        PRDATA <= apb_memory[PADDR];
        PSLVERR <= (PADDR > 25);
    end else if (PSEL && PENABLE && PWRITE) begin
        PREADY <= 1;
        apb_memory[PADDR] <= PWDATA;
        PSLVERR <= (PADDR > 25);
    end else begin
        PREADY <= 0;
        PSLVERR <= 0;
    end
end

// Clock Generation
always #5 ACLK = ~ACLK; // 100 MHz
always #10 PCLK = ~PCLK; // 50 MHz

// Reset Task
task automatic reset_dut();
    begin
        ARESETN = 0; PRESETN = 0;
        S_ARADDR = 0; S_ARVALID = 0; S_RREADY = 0;
        S_AWADDR = 0; S_AWVALID = 0; S_WDATA = 0; S_WSTRB = 0; S_WVALID = 0; S_BREADY = 0;
        repeat (5) @(posedge ACLK);
        repeat (5) @(posedge PCLK);
        ARESETN = 1; PRESETN = 1;
        repeat (2) @(posedge ACLK);
    end
endtask

// AXI4-Lite Write Task
task automatic axi_write(input [ADDRESS-1:0] addr, input [DATA_WIDTH-1:0] data);
    begin
        @(posedge ACLK);
        S_AWADDR = addr;
        S_AWVALID = 1;
        S_WDATA = data;
        S_WSTRB = 4'b1111;
        S_WVALID = 1;
        S_BREADY = 1;
        wait (S_AWREADY && S_WREADY);
        @(posedge ACLK);
        S_AWVALID = 0;
        S_WVALID = 0;
        wait (S_BVALID);
        @(posedge ACLK);
        S_BREADY = 0;
        if (S_BRESP != 2'b00) $display("Write Error: S_BRESP = %b at address %h", S_BRESP, addr);
    end
endtask

// AXI4-Lite Read Task
task automatic axi_read(input [ADDRESS-1:0] addr, output [DATA_WIDTH-1:0] data);
    begin
        @(posedge ACLK);
        S_ARADDR = addr;
        S_ARVALID = 1;
        S_RREADY = 1;
        wait (S_ARREADY);
        @(posedge ACLK);
        S_ARVALID = 0;
        wait (S_RVALID);
        data = S_RDATA;
        @(posedge ACLK);
        #100;
        S_RREADY = 0;
        if (S_RRESP != 2'b00) $display("Read Error: S_RRESP = %b at address %h", S_RRESP, addr);
    end
endtask

// Main Test Sequence
logic [DATA_WIDTH-1:0] rdata;
initial begin
    $display("Starting AXI4-Lite to APB3 Bridge Testbench");
    $dumpfile("axi_to_apb_bridge_tb.vcd");
    $dumpvars(0, axi_to_apb_bridge_tb1);

    // Test 1: Reset
    $display("Test 1: Reset");
    reset_dut();

    // Test 2: Multiple Writes
    $display("Test 2: Multiple AXI Writes");
    
    axi_write(32'h5, 32'hFACECAFE);
    axi_write(32'h1, 32'hABCDEF12);
    axi_write(32'h2, 32'hABCDEF13);
    axi_write(32'h3, 32'hFACECA14);
    axi_write(32'h4, 32'hABCDEF15);
//    axi_write(32'h4, 32'hABCDEF16);
#2;


    // Test 3: Multiple Reads
    $display("Test 3: Multiple AXI Reads");
    axi_read(32'h3, rdata);
    $display("Read data from 0x0 = %h", rdata);
    axi_read(32'h1, rdata);
    $display("Read data from 0x1 = %h", rdata);
    axi_read(32'h2, rdata);
    $display("Read data from 0x2 = %h", rdata);

    // Test 4: Back-to-Back Transactions (Stress Test)
    
 
   
    $display("Test 4: Back-to-Back Write/Read");
    axi_write(32'h5, 32'hDEADBEEF);
  
    axi_read(32'h5, rdata);
    $display("Read data from 0x5 = %h", rdata);
    axi_write(32'h6, 32'hCAFEBABE);
    
  
    axi_read(32'h6, rdata);
    $display("Read data from 0x6 = %h", rdata);

    // Test 5: Error Condition (Invalid Address)
    $display("Test 5: Error on Invalid Address");
    axi_write(32'h26, 32'hABCDEF90); // Should trigger PSLVERR
    axi_read(32'h26, rdata); // Should show error response

    $display("All tests completed.");
    #1000 $finish;
end

// Monitor
initial begin
    $monitor("Time=%0t ACLK=%b PCLK=%b PSEL=%b PENABLE=%b PWRITE=%b PADDR=%h PWDATA=%h PRDATA=%h PREADY=%b PSLVERR=%b S_RVALID=%b S_RDATA=%h",
             $time, ACLK, PCLK, PSEL, PENABLE, PWRITE, PADDR, PWDATA, PRDATA, PREADY, PSLVERR, S_RVALID, S_RDATA);
end

endmodule
