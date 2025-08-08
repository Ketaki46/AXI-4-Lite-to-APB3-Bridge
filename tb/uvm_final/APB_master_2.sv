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
    
    // FIXED: Add registered flags for proper timing
    reg wr_flag_reg, rd_flag_reg;
    reg transaction_complete;

    // FIXED: Proper PWRITE assignment
    always @(posedge PCLK or negedge PRESETn) begin
        if (~PRESETn) begin
            PWRITE <= 1'b0;
        end else if (current_state == SETUP) begin
            PWRITE <= write_bit;
        end
    end

    // FIXED: Proper sequential logic with registered flags
    always @(posedge PCLK or negedge PRESETn) begin
        if (~PRESETn) begin
            current_state <= IDLE;
            rd_flag_reg <= 1'b0;
            wr_flag_reg <= 1'b0;
            PSEL <= 0;
            PENABLE <= 0;
            PADDR <= 32'b0;
            PWDATA <= 32'b0;
            transaction_complete <= 1'b0;
        end else begin
            current_state <= next_state;
            
            // FIXED: Register flags for proper timing
            wr_flag_reg <= wr_flag;
            rd_flag_reg <= rd_flag;
            
            // FIXED: Address assignment in proper state
            if (current_state == IDLE && next_state == SETUP) begin
                if (write_bit) begin
                    PADDR <= write_addr_pkt[31:0];
                    PWDATA <= write_data_pkt[31:0];
                    $display("Time: %0t APB setup phase write: PADDR=%0h,PWDATA=%0h", $time, write_addr_pkt[31:0], write_data_pkt[31:0]);
                end else begin
                    PADDR <= read_addr_pkt[31:0];
                    $display("Time: %0t APB setup phase read: PADDR=%0h", $time, read_addr_pkt[31:0]);
                end
            end
            
            // Track transaction completion
            transaction_complete <= (current_state == ACCESS) && PREADY;
        end
    end

    // FIXED: Improved combinational logic
    always @(*) begin
        next_state = current_state;
        PSEL = 0;
        PENABLE = 0;
        wr_flag = 1'b0;
        rd_flag = 1'b0;
        
        case (current_state)
            IDLE: begin
                if (req_bit && !PSLVERR) begin
                    next_state = SETUP;
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
                
                if (PREADY) begin
                    // FIXED: Assert flags when transaction completes
                    if (PWRITE) begin
                        wr_flag = 1'b1;
                    end else begin
                        rd_flag = 1'b1;
                    end
                    
                    // FIXED: Check for next transaction
                    if (req_bit && !PSLVERR) begin
                        next_state = SETUP; // Continue to next transaction
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
    

//     always @(posedge PCLK) begin
//         $display("Time: %0t State: %s, req_bit=%b, write_bit=%b, PREADY=%b, wr_flag=%b, rd_flag=%b", 
//                  $time, current_state.name(), req_bit, write_bit, PREADY, wr_flag, rd_flag);
//     end

endmodule
