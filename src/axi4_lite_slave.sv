`timescale 1ns / 1ps

module axi4_lite_slave #(
    parameter DATA_WIDTH = 32,
    parameter ADDRESS = 32
) (
    // Global Signals
    input ACLK,
    input ARESETN,
    // Read Address Channel INPUTS
    input [ADDRESS-1:0] S_ARADDR,
    input S_ARVALID,
    // Read Data Channel INPUTS
    input S_RREADY,
    input rdata_rempty, // From read data FIFO
    input PSLVERR, // From APB slave
    // Write Address Channel INPUTS
    input [ADDRESS-1:0] S_AWADDR,
    input S_AWVALID,
    // Write Data Channel INPUTS
    input [DATA_WIDTH-1:0] S_WDATA,
    input [3:0] S_WSTRB,
    input S_WVALID,
    // Write Response Channel INPUTS
    input S_BREADY,
    input [DATA_WIDTH-1:0] rdata,
    // Read Address Channel OUTPUTS
    output logic S_ARREADY,
    // Read Data Channel OUTPUTS
    output logic [DATA_WIDTH-1:0] S_RDATA,
    output logic [1:0] S_RRESP,
    output logic S_RVALID,
    // Write Address Channel OUTPUTS
    output logic S_AWREADY,
    output logic S_WREADY,
    // Write Response Channel OUTPUTS
    output logic [1:0] S_BRESP,
    output logic S_BVALID
);

    localparam no_of_registers = 32;
    logic [DATA_WIDTH-1:0] register [no_of_registers-1:0];
    logic [ADDRESS-1:0] addr;
    logic write_addr;
    logic write_data;

    typedef enum logic [2:0] {IDLE, WRITE_CHANNEL, WRESP_CHANNEL, RADDR_CHANNEL, RDATA_CHANNEL} state_type;
    state_type state, next_state;

    // AR
    assign S_ARREADY = (state == RADDR_CHANNEL) ? 1 : 0;

    // R
    assign S_RVALID = (state == RDATA_CHANNEL && !rdata_rempty) ? 1 : 0;
     assign S_RDATA = rdata ;
//    assign S_RDATA = (state == RDATA_CHANNEL) ? rdata : 0; // Direct FIFO output, no glitches
    assign S_RRESP = (state == RDATA_CHANNEL && PSLVERR) ? 2'b10 : 2'b00; // SLVERR if PSLVERR is high

    // AW
    assign S_AWREADY = (state == WRITE_CHANNEL) ? 1 : 0;

    // W
    assign S_WREADY = (state == WRITE_CHANNEL) ? 1 : 0;
    assign write_addr = S_AWVALID && S_AWREADY;
    assign write_data = S_WREADY && S_WVALID;

    // B
    assign S_BVALID = (state == WRESP_CHANNEL) ? 1 : 0;
    assign S_BRESP = (state == WRESP_CHANNEL) ? 0 : 0;

    integer i;
    always_ff @(posedge ACLK) begin
        if (~ARESETN) begin
            for (i = 0; i < no_of_registers; i++) begin
                register[i] <= 32'b0;
            end
        end else if (state == WRITE_CHANNEL && write_addr && write_data) begin
            register[S_AWADDR] <= S_WDATA;
        end else if (state == RADDR_CHANNEL && S_ARVALID && S_ARREADY) begin
            addr <= S_ARADDR;
        end
    end

    always_ff @(posedge ACLK) begin
        if (!ARESETN) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

    always_comb begin
        case (state)
            IDLE: begin
                if (S_AWVALID) begin
                    next_state = WRITE_CHANNEL;
                end else if (S_ARVALID) begin
                    next_state = RADDR_CHANNEL;
                end else begin
                    next_state = IDLE;
                end
            end
            RADDR_CHANNEL: begin
                if (S_ARVALID && S_ARREADY) begin
                    next_state = RDATA_CHANNEL;
                end else begin
                    next_state = RADDR_CHANNEL;
                end
            end
            RDATA_CHANNEL: begin
                if (S_RVALID && S_RREADY && !rdata_rempty) begin // Added !rdata_rempty to prevent overlap
                    next_state = IDLE;
                end else begin
                    next_state = RDATA_CHANNEL;
                end
            end
            WRITE_CHANNEL: begin
                if (write_addr && write_data) begin
                    next_state = WRESP_CHANNEL;
                end else begin
                    next_state = WRITE_CHANNEL;
                end
            end
            WRESP_CHANNEL: begin
                if (S_BVALID && S_BREADY) begin
                    next_state = IDLE;
                end else begin
                    next_state = WRESP_CHANNEL;
                end
            end
            default: next_state = IDLE;
        endcase
    end
endmodule
