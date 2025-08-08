

`timescale 1ns / 1ps

module axi_to_apb_bridge #(
    parameter DATA_WIDTH = 32,
    parameter ADDRESS = 32,
    parameter FIFO_ASIZE = 3
) (
    // AXI4-Lite Interface
    input ACLK, input ARESETN,
    input PCLK, input PRESETN,
    // Read Address Channel
    input [ADDRESS-1:0] S_ARADDR, input S_ARVALID, output wire S_ARREADY,
    // Read Data Channel
    input S_RREADY, output wire [DATA_WIDTH-1:0] S_RDATA, output wire [1:0] S_RRESP, output wire S_RVALID,
    // Write Address Channel
    input [ADDRESS-1:0] S_AWADDR, input S_AWVALID, output wire S_AWREADY,
    // Write Data Channel
    input [DATA_WIDTH-1:0] S_WDATA, input [3:0] S_WSTRB, input S_WVALID, output wire S_WREADY,
    // Write Response Channel
    input S_BREADY, output wire [1:0] S_BRESP, output wire S_BVALID,
    // APB3 Interface
    output wire PSEL, output wire PENABLE, output wire PWRITE, output wire [ADDRESS-1:0] PADDR,
    output wire [DATA_WIDTH-1:0] PWDATA, input [DATA_WIDTH-1:0] PRDATA, input PREADY, input PSLVERR
);

    // FIFO signals for clock domain crossing
    wire [ADDRESS-1:0] waddr_wdata, raddr_wdata, raddr_rdata;
    wire [DATA_WIDTH+3:0] wdata_wdata, wdata_rdata;
    wire [DATA_WIDTH-1:0] rdata_wdata, rdata_rdata;
    wire waddr_wfull, waddr_rempty, wdata_wfull, wdata_rempty;
    wire raddr_wfull, raddr_rempty, rdata_wfull, rdata_rempty;
    wire waddr_winc, waddr_rinc, wdata_winc, wdata_rinc;
    wire raddr_winc, raddr_rinc, rdata_rinc;  //rdata_winc
    reg rdata_winc;

    // Synchronized empty flags for cross-clock domain
    reg waddr_rempty_sync, wdata_rempty_sync, raddr_rempty_sync;

    // Request and write/read control signals
    wire req_bit;
    reg write_bit;

    // Instantiate AXI4-Lite Slave
    axi4_lite_slave #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDRESS(ADDRESS)
    ) axi_slave (
        .ACLK(ACLK), .ARESETN(ARESETN),
        .S_ARADDR(S_ARADDR), .S_ARVALID(S_ARVALID), .S_ARREADY(S_ARREADY),
        .S_RREADY(S_RREADY), .rdata_rempty(rdata_rempty), .PSLVERR(PSLVERR),
        .S_AWADDR(S_AWADDR), .S_AWVALID(S_AWVALID), .S_AWREADY(S_AWREADY),
        .S_WDATA(S_WDATA), .S_WSTRB(S_WSTRB), .S_WVALID(S_WVALID), .S_WREADY(S_WREADY),
        .S_BREADY(S_BREADY), .S_BRESP(S_BRESP), .S_BVALID(S_BVALID),
        .rdata(rdata_rdata), .S_RDATA(S_RDATA), .S_RRESP(S_RRESP), .S_RVALID(S_RVALID)
    );

    // Write Address FIFO (AXI to APB)
    fifo #(
        .DSIZE(ADDRESS), .ASIZE(FIFO_ASIZE)
    ) waddr_fifo (
        .rdata(waddr_wdata), .wfull(waddr_wfull), .rempty(waddr_rempty),
        .wdata(S_AWADDR), .winc(waddr_winc), .wclk(ACLK), .wrst_n(ARESETN),
        .rinc(waddr_rinc), .rclk(PCLK), .rrst_n(PRESETN)
    );

    // Write Data FIFO (AXI to APB)
    fifo #(
        .DSIZE(DATA_WIDTH + 4), .ASIZE(FIFO_ASIZE)
    ) wdata_fifo (
        .rdata(wdata_rdata), .wfull(wdata_wfull), .rempty(wdata_rempty),
        .wdata({S_WDATA, S_WSTRB}), .winc(wdata_winc), .wclk(ACLK), .wrst_n(ARESETN),
        .rinc(wdata_rinc), .rclk(PCLK), .rrst_n(PRESETN)
    );

    // Read Address FIFO (AXI to APB)
    fifo #(
        .DSIZE(ADDRESS), .ASIZE(FIFO_ASIZE)
    ) raddr_fifo (
        .rdata(raddr_rdata), .wfull(raddr_wfull), .rempty(raddr_rempty),
        .wdata(S_ARADDR), .winc(raddr_winc), .wclk(ACLK), .wrst_n(ARESETN),
        .rinc(raddr_rinc), .rclk(PCLK), .rrst_n(PRESETN)
    );

    // Read Data FIFO (APB to AXI)
    fifo #(
        .DSIZE(DATA_WIDTH), .ASIZE(FIFO_ASIZE)
    ) rdata_fifo (
        .rdata(rdata_rdata), .wfull(rdata_wfull), .rempty(rdata_rempty),
        .wdata(PRDATA), .winc(rdata_winc), .wclk(PCLK), .wrst_n(PRESETN),
        .rinc(rdata_rinc), .rclk(ACLK), .rrst_n(ARESETN)
    );

    // Synchronization of empty flags across clock domains (simplified for clarity)
    always @(posedge PCLK or negedge PRESETN) begin
        if (!PRESETN) begin
            waddr_rempty_sync <= 1;
            wdata_rempty_sync <= 1;
            raddr_rempty_sync <= 1;
        end else begin
            waddr_rempty_sync <= waddr_rempty;
            wdata_rempty_sync <= wdata_rempty;
            raddr_rempty_sync <= raddr_rempty;
        end
    end

    // AXI side FIFO control signals
    assign waddr_winc = S_AWVALID && S_AWREADY && !waddr_wfull;
    assign wdata_winc = S_WVALID && S_WREADY && !wdata_wfull;
    assign raddr_winc = S_ARVALID && S_ARREADY && !raddr_wfull && !rdata_wfull;
    assign rdata_rinc = S_RVALID && S_RREADY && !rdata_rempty;

    // Request detection for APB transactions
    assign req_bit = !waddr_rempty_sync || !raddr_rempty_sync;

    // Write or read operation decision (prioritize write over read)
    always @(posedge PCLK) begin
        if (!waddr_rempty_sync && !wdata_rempty_sync)
            write_bit = 1;
        else if (!raddr_rempty_sync)
            write_bit = 0;
        else
            write_bit = 0;
    end

    // APB Master instantiation with corrected signals
    wire [31:0] write_addr_pkt, write_data_pkt, read_addr_pkt;
    assign write_addr_pkt = waddr_wdata;
    assign write_data_pkt = wdata_rdata[DATA_WIDTH+3:4];
    assign read_addr_pkt = raddr_rdata;

    wire rd_flag, wr_flag;
    APB_master_2 #(
        .DSIZE(DATA_WIDTH), .ASIZE(ADDRESS)
    ) apb_master (
        .PCLK(PCLK), .PRESETn(PRESETN),
        .write_addr_pkt(write_addr_pkt), .write_data_pkt(write_data_pkt),
        .read_addr_pkt(read_addr_pkt), .PRDATA(PRDATA), .PREADY(PREADY), .PSLVERR(PSLVERR),
        .req_bit(req_bit), .write_bit(write_bit),
        .PADDR(PADDR), .PWDATA(PWDATA), .PSEL(PSEL), .PENABLE(PENABLE), .PWRITE(PWRITE),
        .wr_flag(wr_flag), .rd_flag(rd_flag)
    );
    reg [DATA_WIDTH-1:0]  pwrite1;
   always @(posedge PCLK or negedge PRESETN) begin
        if (!PRESETN) begin
           pwrite1 <=0;
        end else begin
           pwrite1<=PRDATA;
        end
    end
    
    reg rdata_inc_flag;
   assign  rdata_inc_flag =(pwrite1 != PRDATA) ? 1:0;

   //  APB side FIFO control signals (corrected to prevent stalls)
    assign waddr_rinc = wr_flag && !waddr_rempty_sync;
    assign wdata_rinc = wr_flag && !wdata_rempty_sync;
    assign raddr_rinc = rd_flag && !raddr_rempty_sync;
    assign rdata_winc = /*rd_flag &&*/  !rdata_wfull && (PRDATA !== {DATA_WIDTH{1'bx}}) && PREADY && rdata_inc_flag;
   
endmodule
