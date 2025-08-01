`timescale 1ns/1ps

`include "uvm_macros.svh"
import uvm_pkg::*;

// APB Interface
interface apb_if (
    input logic pclk,
    input logic presetn
);
    logic [31:0] paddr;
    logic [31:0] pwdata;
    logic [31:0] prdata;
    logic psel;
    logic penable;
    logic pwrite;
    logic pready;
    logic pslverr;

    // Master input signals for APB Master
    logic [35:0] write_addr_pkt;
    logic [35:0] write_data_pkt;
    logic [35:0] read_addr_pkt;
    logic wr_flag;
    logic rd_flag;

    // Clocking block for driver
    clocking cb @(posedge pclk);
        input presetn, pready, prdata, pslverr, wr_flag, rd_flag;
        output write_addr_pkt, write_data_pkt, read_addr_pkt;
    endclocking

    modport master (clocking cb);
    modport dut (input pclk, presetn, paddr, pwdata, psel, penable, pwrite, output prdata, pready, pslverr);
endinterface

// APB Transaction
class apb_transaction extends uvm_sequence_item;
    rand logic [31:0] addr;
    rand logic [31:0] data;
    rand bit write;
    logic pready;
    logic [31:0] rdata;
    logic pslverr;

    `uvm_object_utils_begin(apb_transaction)
        `uvm_field_int(addr, UVM_ALL_ON)
        `uvm_field_int(data, UVM_ALL_ON)
        `uvm_field_int(write, UVM_ALL_ON)
        `uvm_field_int(rdata, UVM_ALL_ON)
        `uvm_field_int(pslverr, UVM_ALL_ON)
    `uvm_object_utils_end

    function new(string name = "apb_transaction");
        super.new(name);
    endfunction
endclass

// APB Scoreboard
class apb_scoreboard extends uvm_scoreboard;
    uvm_analysis_imp #(apb_transaction, apb_scoreboard) ap;
    logic [31:0] mem [0:255]; // Fixed-size memory model

    `uvm_component_utils(apb_scoreboard)

    function new(string name, uvm_component parent);
        super.new(name, parent);
        ap = new("ap", this);
    endfunction

    function void write(apb_transaction tx);
        if (tx.write && !tx.pslverr) begin
            mem[tx.addr[7:0]] = tx.data;
            `uvm_info("SB", $sformatf("Write: addr=%0h, data=%0h", tx.addr, tx.data), UVM_MEDIUM)
        end else if (!tx.write && !tx.pslverr) begin
            logic [31:0] expected_data;
            expected_data = mem[tx.addr[7:0]];
            if (tx.rdata != expected_data)
                `uvm_error("SB", $sformatf("Read mismatch: addr=%0h, expected=%0h, got=%0h", tx.addr, expected_data, tx.rdata))
            else
                `uvm_info("SB", $sformatf("Read: addr=%0h, data=%0h", tx.addr, tx.rdata), UVM_MEDIUM)
        end
        if (tx.pslverr && tx.addr >= 256)
            `uvm_info("SB", $sformatf("Correct error detected: addr=%0h", tx.addr), UVM_MEDIUM)
        else if (tx.pslverr && tx.addr < 256)
            `uvm_error("SB", $sformatf("Unexpected error: addr=%0h", tx.addr))
    endfunction
endclass

// APB Coverage
class apb_coverage extends uvm_component;
    `uvm_component_utils(apb_coverage)

    uvm_analysis_imp #(apb_transaction, apb_coverage) ap;
    apb_transaction tx;

    covergroup apb_cg;
        option.per_instance = 1;
        addr: coverpoint tx.addr {
            bins addr_low = {[0:100]};
            bins addr_high = {[101:255]};
            bins addr_err = {[256:4294967295]};
        }
        write: coverpoint tx.write {
            bins write_op = {1};
            bins read_op = {0};
        }
        pslverr: coverpoint tx.pslverr {
            bins no_err = {0};
            bins err = {1};
        }
        cross addr, write;
        cross write, pslverr;
    endgroup

    function new(string name, uvm_component parent);
        super.new(name, parent);
        ap = new("ap", this);
        apb_cg = new();
    endfunction

    function void write(apb_transaction t);
        tx = t;
        apb_cg.sample();
    endfunction
endclass

// APB Sequence
class apb_sequence extends uvm_sequence #(apb_transaction);
    `uvm_object_utils(apb_sequence)

    function new(string name = "apb_sequence");
        super.new(name);
    endfunction

    task body();
        apb_transaction tx;
        // Test 1: Normal write/read
        repeat(5) begin
            tx = apb_transaction::type_id::create("tx");
            start_item(tx);
            if (!tx.randomize() with { addr inside {[0:15]}; }) begin
                `uvm_error("SEQ", "Randomization failed")
            end
            finish_item(tx);
        end
        // Test 2: Error condition
        tx = apb_transaction::type_id::create("tx");
        start_item(tx);
        if (!tx.randomize() with { addr == 256; }) begin
            `uvm_error("SEQ", "Randomization failed")
        end
        finish_item(tx);
        // Test 3: Back-to-back transactions
        repeat(5) begin
            tx = apb_transaction::type_id::create("tx");
            start_item(tx);
            if (!tx.randomize() with { addr inside {[0:15]}; write == 1; }) begin
                `uvm_error("SEQ", "Randomization failed")
            end
            finish_item(tx);
            tx = apb_transaction::type_id::create("tx");
            start_item(tx);
            if (!tx.randomize() with { addr == tx.addr; write == 0; }) begin
                `uvm_error("SEQ", "Randomization failed")
            end
            finish_item(tx);
        end
    endtask
endclass

// APB Driver
class apb_driver extends uvm_driver #(apb_transaction);
    virtual apb_if vif;
    `uvm_component_utils(apb_driver)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual apb_if)::get(this, "", "apb_vif", vif))
            `uvm_fatal("DRV", "No virtual interface set")
    endfunction

    task run_phase(uvm_phase phase);
        super.run_phase(phase);
        vif.write_addr_pkt = 0;
        vif.write_data_pkt = 0;
        vif.read_addr_pkt = 0;
        forever begin
            apb_transaction tx;
            seq_item_port.get_next_item(tx);
            drive_transaction(tx);
            seq_item_port.item_done();
        end
    endtask

    task drive_transaction(apb_transaction tx);
        @(vif.cb);
        if (!vif.cb.presetn) begin
            @(posedge vif.cb.presetn);
        end
        // Drive master inputs
        if (tx.write) begin
            vif.write_addr_pkt = {1'b1, 1'b1, 30'h0, tx.addr[3:0]}; // Valid, write bit, address
            vif.write_data_pkt = {1'b1, 1'b0, tx.data}; // Valid, data
            vif.read_addr_pkt = 0;
        end else begin
            vif.write_addr_pkt = 0;
            vif.write_data_pkt = 0;
            vif.read_addr_pkt = {1'b1, 1'b0, 30'h0, tx.addr[3:0]}; // Valid, read bit, address
        end
        @(vif.cb);
        // Wait for completion
        if (tx.write) begin
            while (!vif.cb.wr_flag) @(vif.cb);
        end else begin
            while (!vif.cb.rd_flag) @(vif.cb);
        end
        // Capture response
        tx.rdata = vif.cb.prdata;
        tx.pslverr = vif.cb.pslverr;
        // Clear inputs
        vif.write_addr_pkt = 0;
        vif.write_data_pkt = 0;
        vif.read_addr_pkt = 0;
        @(vif.cb);
    endtask
endclass

// APB Monitor
class apb_monitor extends uvm_monitor;
    virtual apb_if vif;
    uvm_analysis_port #(apb_transaction) ap;

    `uvm_component_utils(apb_monitor)

    function new(string name, uvm_component parent);
        super.new(name, parent);
        ap = new("ap", this);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual apb_if)::get(this, "", "apb_vif", vif))
            `uvm_fatal("MON", "No virtual interface set")
    endfunction

    task run_phase(uvm_phase phase);
        super.run_phase(phase);
        forever begin
            apb_transaction tx = apb_transaction::type_id::create("tx");
            @(posedge vif.pclk);
            if (vif.psel && !vif.penable) begin
                tx.addr = vif.paddr;
                tx.write = vif.pwrite;
                if (tx.write)
                    tx.data = vif.pwdata;
                @(posedge vif.pclk);
                if (vif.penable && vif.pready) begin
                    tx.rdata = vif.prdata;
                    tx.pslverr = vif.pslverr;
                    ap.write(tx);
                end
            end
        end
    endtask
endclass

// APB Agent
class apb_agent extends uvm_agent;
    apb_driver driver;
    apb_monitor monitor;
    uvm_sequencer #(apb_transaction) sequencer;

    `uvm_component_utils(apb_agent)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        monitor = apb_monitor::type_id::create("monitor", this);
        if (get_is_active()) begin
            driver = apb_driver::type_id::create("driver", this);
            sequencer = uvm_sequencer#(apb_transaction)::type_id::create("sequencer", this);
        end
    endfunction

    function void connect_phase(uvm_phase phase);
        if (get_is_active())
            driver.seq_item_port.connect(sequencer.seq_item_export);
    endfunction
endclass

// APB Environment
class apb_env extends uvm_env;
    apb_agent agent;
    apb_scoreboard scoreboard;
    apb_coverage coverage;

    `uvm_component_utils(apb_env)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        agent = apb_agent::type_id::create("agent", this);
        scoreboard = apb_scoreboard::type_id::create("scoreboard", this);
        coverage = apb_coverage::type_id::create("coverage", this);
    endfunction

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        agent.monitor.ap.connect(scoreboard.ap);
        agent.monitor.ap.connect(coverage.ap);
    endfunction
endclass

// APB Test
class apb_test extends uvm_test;
    apb_env env;
    `uvm_component_utils(apb_test)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        env = apb_env::type_id::create("env", this);
        uvm_config_db#(uvm_bitstream_t)::set(this, "env.agent", "is_active", UVM_ACTIVE);
    endfunction

    task run_phase(uvm_phase phase);
        apb_sequence seq;
        phase.raise_objection(this);
        seq = apb_sequence::type_id::create("seq");
        seq.start(env.agent.sequencer);
        #200ns;
        phase.drop_objection(this);
    endtask
endclass

// APB Master
module APB_master_2 #(
    parameter DSIZE = 32,
    parameter ASIZE = 4
) (
    input PCLK,
    input PRESETn,
    input [35:0] write_addr_pkt, write_data_pkt, read_addr_pkt,
    input [DSIZE-1:0] PRDATA,
    input PREADY,
    input PSLVERR,
    output reg [ASIZE-1:0] PADDR,
    output reg [DSIZE-1:0] PWDATA,
    output reg PSEL,
    output reg PENABLE,
    output reg PWRITE,
    output reg wr_flag,
    output reg rd_flag
);
    typedef enum logic [1:0] {
        IDLE   = 2'b00,
        SETUP  = 2'b01,
        ACCESS = 2'b10
    } apb_state;

    apb_state current_state, next_state;
    reg write_bit;
    reg read_bit;

    wire req;
    assign req = write_addr_pkt[35] | read_addr_pkt[35];

    always @(posedge PCLK or negedge PRESETn) begin
        if (~PRESETn) begin
            current_state <= IDLE;
            wr_flag <= 1'b0;
            rd_flag <= 1'b0;
            PSEL <= 0;
            PENABLE <= 0;
            PWRITE <= 0;
            PADDR <= 0;
            PWDATA <= 0;
        end else begin
            current_state <= next_state;
            if (current_state == SETUP) begin
                write_bit = write_addr_pkt[34];
                read_bit = read_addr_pkt[34];
                PWRITE = write_bit ? 1 : 0;
                if (PWRITE) begin
                    PADDR = write_addr_pkt[3:0];
                    PWDATA = write_data_pkt[31:0];
                end else begin
                    PADDR = read_addr_pkt[3:0];
                end
            end
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
                if (req) begin
                    if (PSLVERR) begin
                        next_state = IDLE;
                    end else begin
                        next_state = SETUP;
                    end
                end else begin
                    next_state = IDLE;
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
                    if (PWRITE) begin
                        wr_flag = 1'b1;
                        rd_flag = 1'b0;
                    end else begin
                        rd_flag = 1'b1;
                        wr_flag = 1'b0;
                    end
                end
                if (PREADY && req && !PSLVERR) begin
                    next_state = SETUP;
                end else if (PREADY && (!req || PSLVERR)) begin
                    next_state = IDLE;
                end else begin
                    next_state = ACCESS;
                end
            end
            default: begin
                next_state = IDLE;
            end
        endcase
    end
endmodule

// APB Slave DUT
module apb_slave (
    input logic pclk,
    input logic presetn,
    input logic [31:0] paddr,
    input logic [31:0] pwdata,
    input logic psel,
    input logic penable,
    input logic pwrite,
    output logic [31:0] prdata,
    output logic pready,
    output logic pslverr
);
    logic [31:0] mem [0:255];
    logic [31:0] addr_reg;
    logic write_reg;

    always @(posedge pclk or negedge presetn) begin
        if (!presetn) begin
            pready <= 0;
            pslverr <= 0;
            prdata <= 0;
            addr_reg <= 0;
            write_reg <= 0;
        end else begin
            if (psel && !penable) begin
                addr_reg <= paddr;
                write_reg <= pwrite;
                pready <= 0;
            end
            if (psel && penable) begin
                pready <= 1;
                pslverr <= (paddr >= 256);
                if (pwrite && !pslverr)
                    mem[paddr[7:0]] <= pwdata;
                else if (!pwrite && !pslverr)
                    prdata <= mem[paddr[7:0]];
                else
                    prdata <= 0;
            end else begin
                pready <= 0;
                pslverr <= 0;
            end
        end
    end
endmodule

// Top Module
module tb_top;
    logic pclk;
    logic presetn;

    // Clock generation
    initial begin
        pclk = 0;
        forever #5 pclk = ~pclk;
    end

    // Reset generation
    initial begin
        presetn = 0;
        #20;
        presetn = 1;
    end

    // Interface and DUT instantiation
    apb_if apb_if_inst (.pclk(pclk), .presetn(presetn));
    APB_master_2 #(.DSIZE(32), .ASIZE(4)) apb_master (
        .PCLK(pclk),
        .PRESETn(presetn),
        .write_addr_pkt(apb_if_inst.write_addr_pkt),
        .write_data_pkt(apb_if_inst.write_data_pkt),
        .read_addr_pkt(apb_if_inst.read_addr_pkt),
        .PRDATA(apb_if_inst.prdata),
        .PREADY(apb_if_inst.pready),
        .PSLVERR(apb_if_inst.pslverr),
        .PADDR(apb_if_inst.paddr),
        .PWDATA(apb_if_inst.pwdata),
        .PSEL(apb_if_inst.psel),
        .PENABLE(apb_if_inst.penable),
        .PWRITE(apb_if_inst.pwrite),
        .wr_flag(apb_if_inst.wr_flag),
        .rd_flag(apb_if_inst.rd_flag)
    );
    apb_slave dut (
        .pclk(pclk),
        .presetn(presetn),
        .paddr(apb_if_inst.paddr),
        .pwdata(apb_if_inst.pwdata),
        .prdata(apb_if_inst.prdata),
        .psel(apb_if_inst.psel),
        .penable(apb_if_inst.penable),
        .pwrite(apb_if_inst.pwrite),
        .pready(apb_if_inst.pready),
        .pslverr(apb_if_inst.pslverr)
    );

    initial begin
        uvm_config_db#(virtual apb_if)::set(null, "uvm_test_top", "apb_vif", apb_if_inst);
        run_test("apb_test");
    end
endmodule
