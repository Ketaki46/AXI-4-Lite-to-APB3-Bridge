`timescale 1ns / 1ps

typedef enum logic [1:0] {
    IDLE = 2'b00,
    SETUP = 2'b01,
    ACCESS = 2'b10
} apb_state;

module APB_master_2 #(
    parameter DSIZE = 32,
    parameter ASIZE = 32
) (
    input PCLK,
    input PRESETn,
    input [31:0] write_addr_pkt, write_data_pkt, read_addr_pkt,
    input [DSIZE-1:0] PRDATA,
    input PREADY,
    input PSLVERR,
    input req_bit, write_bit,
    output reg [ASIZE-1:0] PADDR,
    output reg [DSIZE-1:0] PWDATA,
    output reg PSEL,
    output reg PENABLE,
    output reg PWRITE,
    output reg wr_flag,
    output reg rd_flag
);

    apb_state current_state, next_state;

    assign PWRITE = (write_bit) ? 1 : 0;

    always @(posedge PCLK or negedge PRESETn) begin
        if (~PRESETn) begin
            current_state <= IDLE;
            rd_flag <= 1'b0;
            wr_flag <= 1'b0;
            PSEL <= 0;
            PENABLE <= 0;
            PADDR <= 32'b0;
            PWDATA <= 32'b0;
        end else begin
            current_state <= next_state;
            if (current_state == SETUP) begin
                if (PWRITE) begin
                    PADDR <= write_addr_pkt[31:0];
                    PWDATA <= write_data_pkt[31:0];
                end else begin
                    PADDR <= read_addr_pkt[31:0];
                end
            end
//            else
//                current_state <= next_state;
        end
    end

    always @(*) begin
        next_state = current_state;
        PSEL = 0;
        PENABLE = 0;
        wr_flag = 1'b0;
        rd_flag = 1'b0;
        case (current_state)
            IDLE: begin
                if (req_bit) begin
                    if (PSLVERR) begin
                        next_state = IDLE;
                    end else begin
                        next_state = SETUP;
                    end
                end
            end
            SETUP: begin
                PSEL = 1'b1;
                PENABLE = 1'b0;
                next_state = ACCESS;
            end
            ACCESS: begin
                PSEL = 1'b1;
                PENABLE = 1'b1;
                if (PREADY) begin // Wait for PREADY before flagging
                    if (PWRITE) begin
                        wr_flag = 1'b1;
                        rd_flag = 1'b0;
                    end else begin
                        rd_flag = 1'b1;
                        wr_flag = 1'b0;
                    end
                    if (req_bit && !PSLVERR) begin
                        next_state = SETUP; // Loop to next if more requests
                    end else begin
                        next_state = IDLE;
                    end
                end else begin
                    next_state = ACCESS; // Stay until PREADY
                end
            end
            default: next_state = IDLE;
        endcase
    end
endmodule
