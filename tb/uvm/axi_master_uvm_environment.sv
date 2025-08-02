// axi4_lite_uvm_env_single_file.sv
// This file contains the complete UVM environment for the axi4_lite_slave DUT.
// It includes the DUT, interface, UVM components (sequence item, sequencer, driver, monitors, agent, scoreboard, environment),
// sequences, and the top-level testbench.

`timescale 1ns / 1ps

// Import UVM package
import uvm_pkg::*;
`include "uvm_macros.svh"
// AXI4-Lite Interface
interface axi4_lite_slave_if (input bit ACLK, input bit ARESETN);

  // Parameters (match DUT parameters)
  parameter DATA_WIDTH = 32;
  parameter ADDR_WIDTH = 32; // Renamed from ADDRESS to ADDR_WIDTH for clarity

  // Master to Slave Signals (Inputs to Slave)
  logic [ADDR_WIDTH-1:0] S_ARADDR;
  logic                  S_ARVALID;
  logic                  S_RREADY;

  logic [ADDR_WIDTH-1:0] S_AWADDR;
  logic                  S_AWVALID;
  logic [DATA_WIDTH-1:0] S_WDATA;
  logic [3:0]            S_WSTRB;
  logic                  S_WVALID;
  logic                  S_BREADY;

  // Slave to Master Signals (Outputs from Slave)
  logic                  S_ARREADY;
  logic [DATA_WIDTH-1:0] S_RDATA;
  logic [1:0]            S_RRESP;
  logic                  S_RVALID;
  logic                  S_AWREADY;
  logic                  S_WREADY;
  logic [1:0]            S_BRESP;
  logic                  S_BVALID;

  // Clocking block for the DRIVER (master side)
  // Defines what the driver drives (output) and what it samples (input)
  clocking cb_driver @(posedge ACLK);
    default input #1step output #1; // Sample inputs 1 step after posedge, drive outputs 1 cycle after posedge

    // Signals driven by the master driver
    output S_ARADDR, S_ARVALID, S_RREADY;
    output S_AWADDR, S_AWVALID, S_WDATA, S_WSTRB, S_WVALID, S_BREADY;

    // Signals sampled by the master driver (from the slave)
    input S_ARREADY, S_RDATA, S_RRESP, S_RVALID;
    input S_AWREADY, S_WREADY, S_BRESP, S_BVALID;
  endclocking

  // Clocking block for the MASTER MONITOR (master side)
  // Defines all signals as inputs, as the monitor only observes
  clocking cb_master_monitor @(posedge ACLK);
    default input #1step; // Only inputs for monitoring

    // All AXI signals are inputs from the perspective of a monitor
    input S_ARADDR, S_ARVALID, S_RREADY;
    input S_AWADDR, S_AWVALID, S_WDATA, S_WSTRB, S_WVALID, S_BREADY;
    input S_ARREADY, S_RDATA, S_RRESP, S_RVALID;
    input S_AWREADY, S_WREADY, S_BRESP, S_BVALID;
  endclocking

  // Clocking block for the SLAVE MONITOR (slave side)
  // Defines all signals as inputs, as the monitor only observes
  clocking cb_slave_monitor @(posedge ACLK);
    default input #1step; // Only inputs for monitoring

    // All AXI signals are inputs from the perspective of a monitor
    input S_ARADDR, S_ARVALID, S_RREADY;
    input S_AWADDR, S_AWVALID, S_WDATA, S_WSTRB, S_WVALID, S_BREADY;
    input S_ARREADY, S_RDATA, S_RRESP, S_RVALID;
    input S_AWREADY, S_WREADY, S_BRESP, S_BVALID;
  endclocking

  // Modports for different roles
  // MASTER_DRIVER modport: used by the driver to drive signals
  modport MASTER_DRIVER (
    clocking cb_driver,
    input ACLK, ARESETN
  );

  // MASTER_MONITOR modport: used by the master monitor to sample signals
  modport MASTER_MONITOR (
    clocking cb_master_monitor,
    input ACLK, ARESETN
  );

  // SLAVE_MONITOR modport: used by the slave monitor to sample signals
  modport SLAVE_MONITOR (
    clocking cb_slave_monitor,
    input ACLK, ARESETN
  );

  // DUT modport: used by the top_tb to connect to the DUT
  modport DUT (
    input ACLK, ARESETN,
    input S_ARADDR, S_ARVALID, S_RREADY,
    input S_AWADDR, S_AWVALID, S_WDATA, S_WSTRB, S_WVALID, S_BREADY,
    output S_ARREADY, S_RDATA, S_RRESP, S_RVALID,
    output S_AWREADY, S_WREADY, S_BRESP, S_BVALID
  );

endinterface


// AXI4-Lite Master Sequence Item
class axi4_lite_master_seq_item extends uvm_sequence_item;

  // Transaction type enum - MOVED HERE FORWARD DECLARATION
  typedef enum {WRITE, READ} transaction_type_e;

  // UVM Factory Registration
  `uvm_object_utils_begin(axi4_lite_master_seq_item)
    `uvm_field_enum(transaction_type_e, tr_type, UVM_ALL_ON)
    `uvm_field_int(addr, UVM_ALL_ON | UVM_HEX)
    `uvm_field_int(wdata, UVM_ALL_ON | UVM_HEX)
    `uvm_field_int(wstrb, UVM_ALL_ON | UVM_BIN)
    `uvm_field_int(rdata, UVM_ALL_ON | UVM_HEX)
    `uvm_field_int(resp, UVM_ALL_ON)
  `uvm_object_utils_end

  // Data members
  transaction_type_e tr_type; // Type of transaction (WRITE or READ)
  rand bit [31:0]    addr;    // Address for the transaction
  rand bit [31:0]    wdata;   // Write data
  rand bit [3:0]     wstrb;   // Write strobe (byte enables)
  bit [31:0]         rdata;   // Read data (returned by slave)
  bit [1:0]          resp;    // Response (e.g., OKAY, SLVERR)

  // Constraints
  constraint addr_c { addr inside {[0:31]}; } // Constrain address to be within 32 registers
  constraint wstrb_c { wstrb == 4'hF; } // For simplicity, always enable all bytes for now

  // Constructor
  function new(string name = "axi4_lite_master_seq_item");
    super.new(name);
  endfunction

  // Override do_print for custom printing (optional but good practice)
  virtual function void do_print(uvm_printer printer);
    super.do_print(printer);
    printer.print_field_int("tr_type", tr_type, $bits(tr_type), UVM_DEC);
    printer.print_field_int("addr", addr, $bits(addr), UVM_HEX);
    printer.print_field_int("wdata", wdata, $bits(wdata), UVM_HEX);
    printer.print_field_int("wstrb", wstrb, $bits(wstrb), UVM_BIN);
    printer.print_field_int("rdata", rdata, $bits(rdata), UVM_HEX);
    printer.print_field_int("resp", resp, $bits(resp), UVM_DEC);
  endfunction

endclass


// AXI4-Lite Master Sequencer
class axi4_lite_master_sequencer extends uvm_sequencer #(axi4_lite_master_seq_item);

  // UVM Factory Registration
  `uvm_component_utils(axi4_lite_master_sequencer)

  // Constructor
  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  // Build Phase (optional, but good practice)
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    `uvm_info(get_full_name(), "Building sequencer...", UVM_LOW)
  endfunction

endclass


// AXI4-Lite Master Driver
class axi4_lite_master_driver extends uvm_driver #(axi4_lite_master_seq_item);

  // UVM Factory Registration
  `uvm_component_utils(axi4_lite_master_driver)

  // Virtual interface handle
  virtual axi4_lite_slave_if vif;

  // Constructor
  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  // Build Phase: Get the virtual interface
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    // Get the specific driver clocking block modport
    if (!uvm_config_db #(virtual axi4_lite_slave_if)::get(this, "", "vif", vif)) begin
      `uvm_fatal(get_full_name(), "Virtual interface 'vif' not set for driver")
    end
  endfunction

  // Run Phase: Main driving loop
  virtual task run_phase(uvm_phase phase);
    forever begin
      // Wait for reset to de-assert
      @(posedge vif.ACLK);
      if (!vif.ARESETN) begin
        `uvm_info(get_full_name(), "Waiting for reset de-assertion...", UVM_LOW)
        wait (vif.ARESETN);
        `uvm_info(get_full_name(), "Reset de-asserted. Starting transactions.", UVM_LOW)
      end

      // Get a new sequence item from the sequencer
      seq_item_port.get_next_item(req);

      `uvm_info(get_full_name(), $sformatf("Driving transaction: %s", req.sprint()), UVM_HIGH)

      case (req.tr_type)
        axi4_lite_master_seq_item::WRITE: drive_write_transaction(req);
        axi4_lite_master_seq_item::READ:  drive_read_transaction(req);
        default: `uvm_error(get_full_name(), $sformatf("Invalid transaction type: %s", req.tr_type.name()))
      endcase

      // Item done, signal back to sequencer
      seq_item_port.item_done();
    end
  endtask

  // Task to drive an AXI4-Lite write transaction
  virtual protected task drive_write_transaction(axi4_lite_master_seq_item item);
    // Initialize write channel signals using the driver clocking block
    vif.cb_driver.S_AWVALID <= 0;
    vif.cb_driver.S_WVALID  <= 0;
    vif.cb_driver.S_BREADY  <= 0;

    // 1. Drive Write Address Channel (AW)
    `uvm_info(get_full_name(), $sformatf("Driving AWADDR=0x%0h", item.addr), UVM_HIGH)
    @(vif.cb_driver);
    vif.cb_driver.S_AWADDR  <= item.addr;
    vif.cb_driver.S_AWVALID <= 1;

    // 2. Drive Write Data Channel (W)
    `uvm_info(get_full_name(), $sformatf("Driving WDATA=0x%0h, WSTRB=0x%0h", item.wdata, item.wstrb), UVM_HIGH)
    @(vif.cb_driver);
    vif.cb_driver.S_WDATA   <= item.wdata;
    vif.cb_driver.S_WSTRB   <= item.wstrb;
    vif.cb_driver.S_WVALID  <= 1;

    // Wait for AWREADY and WREADY from slave (sampled via input in cb_driver)
    wait (vif.cb_driver.S_AWREADY && vif.cb_driver.S_WREADY);
    `uvm_info(get_full_name(), "AWREADY and WREADY received.", UVM_HIGH)

    // De-assert AWVALID and WVALID
    @(vif.cb_driver);
    vif.cb_driver.S_AWVALID <= 0;
    vif.cb_driver.S_WVALID  <= 0;

    // 3. Drive Write Response Channel (B)
    `uvm_info(get_full_name(), "Driving BREADY", UVM_HIGH)
    @(vif.cb_driver);
    vif.cb_driver.S_BREADY <= 1;

    // Wait for BVALID from slave (sampled via input in cb_driver)
    wait (vif.cb_driver.S_BVALID);
    `uvm_info(get_full_name(), $sformatf("BVALID received with BRESP=0x%0h", vif.cb_driver.S_BRESP), UVM_HIGH)
    item.resp = vif.cb_driver.S_BRESP; // Capture response

    // De-assert BREADY
    @(vif.cb_driver);
    vif.cb_driver.S_BREADY <= 0;

    // Final idle state for signals
    @(vif.cb_driver);
    vif.cb_driver.S_AWADDR  <= 'X;
    vif.cb_driver.S_WDATA   <= 'X;
    vif.cb_driver.S_WSTRB   <= 'X;
  endtask

  // Task to drive an AXI4-Lite read transaction
  virtual protected task drive_read_transaction(axi4_lite_master_seq_item item);
    // Initialize read channel signals using the driver clocking block
    vif.cb_driver.S_ARVALID <= 0;
    vif.cb_driver.S_RREADY  <= 0;

    // 1. Drive Read Address Channel (AR)
    `uvm_info(get_full_name(), $sformatf("Driving ARADDR=0x%0h", item.addr), UVM_HIGH)
    @(vif.cb_driver);
    vif.cb_driver.S_ARADDR  <= item.addr;
    vif.cb_driver.S_ARVALID <= 1;

    // Wait for ARREADY from slave (sampled via input in cb_driver)
    wait (vif.cb_driver.S_ARREADY);
    `uvm_info(get_full_name(), "ARREADY received.", UVM_HIGH)

    // De-assert ARVALID
    @(vif.cb_driver);
    vif.cb_driver.S_ARVALID <= 0;

    // 2. Drive Read Data Channel (R)
    `uvm_info(get_full_name(), "Driving RREADY", UVM_HIGH)
    @(vif.cb_driver);
    vif.cb_driver.S_RREADY <= 1;

    // Wait for RVALID from slave (sampled via input in cb_driver)
    wait (vif.cb_driver.S_RVALID);
    `uvm_info(get_full_name(), $sformatf("RVALID received with RDATA=0x%0h, RRESP=0x%0h", vif.cb_driver.S_RDATA, vif.cb_driver.S_RRESP), UVM_HIGH)
    item.rdata = vif.cb_driver.S_RDATA; // Capture read data
    item.resp  = vif.cb_driver.S_RRESP; // Capture response

    // De-assert RREADY
    @(vif.cb_driver);
    vif.cb_driver.S_RREADY <= 0;

    // Final idle state for signals
    @(vif.cb_driver);
    vif.cb_driver.S_ARADDR <= 'X;
  endtask

endclass


// AXI4-Lite Master Monitor
class axi4_lite_master_monitor extends uvm_monitor;

  // UVM Factory Registration
  `uvm_component_utils(axi4_lite_master_monitor)

  // Virtual interface handle
  virtual axi4_lite_slave_if vif;

  // Analysis port to send observed transactions to the scoreboard/subscribers
  uvm_analysis_port #(axi4_lite_master_seq_item) ap;

  // Constructor
  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  // Build Phase: Get the virtual interface
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    // Get the specific master monitor clocking block modport
    if (!uvm_config_db #(virtual axi4_lite_slave_if)::get(this, "", "vif", vif)) begin
      `uvm_fatal(get_full_name(), "Virtual interface 'vif' not set for monitor")
    end
    ap = new("ap", this);
  endfunction

  // Run Phase: Main monitoring loop
  virtual task run_phase(uvm_phase phase);
    fork
      monitor_writes();
      monitor_reads();
    join_none
  endtask

  // Task to monitor AXI4-Lite write transactions
  virtual protected task monitor_writes();
    axi4_lite_master_seq_item tr;
    forever begin
      // Wait for AWVALID and WVALID to be asserted (start of a write transaction)
      @(vif.cb_master_monitor); // Use master monitor clocking block
      wait (vif.cb_master_monitor.S_AWVALID && vif.cb_master_monitor.S_WVALID);

      tr = axi4_lite_master_seq_item::type_id::create("tr");
      tr.tr_type = axi4_lite_master_seq_item::WRITE;
      tr.addr    = vif.cb_master_monitor.S_AWADDR;
      tr.wdata   = vif.cb_master_monitor.S_WDATA;
      tr.wstrb   = vif.cb_master_monitor.S_WSTRB;

      `uvm_info(get_full_name(), $sformatf("Observed Master Write Request: addr=0x%0h, wdata=0x%0h", tr.addr, tr.wdata), UVM_HIGH)

      // Wait for BVALID (write response)
      @(vif.cb_master_monitor); // Use master monitor clocking block
      wait (vif.cb_master_monitor.S_BVALID);
      tr.resp = vif.cb_master_monitor.S_BRESP;

      `uvm_info(get_full_name(), $sformatf("Observed Master Write Response: resp=0x%0h", tr.resp), UVM_HIGH)

      // Send the observed transaction
      ap.write(tr);
    end
  endtask

  // Task to monitor AXI4-Lite read transactions
  virtual protected task monitor_reads();
    axi4_lite_master_seq_item tr;
    forever begin
      // Wait for ARVALID to be asserted (start of a read transaction)
      @(vif.cb_master_monitor); // Use master monitor clocking block
      wait (vif.cb_master_monitor.S_ARVALID);

      tr = axi4_lite_master_seq_item::type_id::create("tr");
      tr.tr_type = axi4_lite_master_seq_item::READ;
      tr.addr    = vif.cb_master_monitor.S_ARADDR;

      `uvm_info(get_full_name(), $sformatf("Observed Master Read Request: addr=0x%0h", tr.addr), UVM_HIGH)

      // Wait for RVALID (read data)
      @(vif.cb_master_monitor); // Use master monitor clocking block
      wait (vif.cb_master_monitor.S_RVALID);
      tr.rdata = vif.cb_master_monitor.S_RDATA;
      tr.resp  = vif.cb_master_monitor.S_RRESP;

      `uvm_info(get_full_name(), $sformatf("Observed Master Read Data: rdata=0x%0h, resp=0x%0h", tr.rdata, tr.resp), UVM_HIGH)

      // Send the observed transaction
      ap.write(tr);
    end
  endtask

endclass


// AXI4-Lite Master Agent
class axi4_lite_master_agent extends uvm_agent;

  // UVM Factory Registration
  `uvm_component_utils(axi4_lite_master_agent)

  // Agent components
  axi4_lite_master_sequencer m_sequencer;
  axi4_lite_master_driver    m_driver;
  axi4_lite_master_monitor   m_monitor;

  // Configuration variable to enable/disable active mode
  uvm_active_passive_enum is_active = UVM_ACTIVE;

  // Constructor
  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  // Build Phase: Create agent components
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    // Get active/passive configuration
    if (!uvm_config_db #(uvm_active_passive_enum)::get(this, "", "is_active", is_active)) begin
      `uvm_info(get_full_name(), "is_active not set, defaulting to UVM_ACTIVE", UVM_LOW)
    end

    // Create monitor (always present for both active/passive)
    m_monitor = axi4_lite_master_monitor::type_id::create("m_monitor", this);

    // Create sequencer and driver only if active
    if (is_active == UVM_ACTIVE) begin
      m_sequencer = axi4_lite_master_sequencer::type_id::create("m_sequencer", this);
      m_driver    = axi4_lite_master_driver::type_id::create("m_driver", this);
    end
  endfunction

  // Connect Phase: Connect sequencer to driver
  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    if (is_active == UVM_ACTIVE) begin
      m_driver.seq_item_port.connect(m_sequencer.seq_item_export);
    end
  endfunction

endclass


// AXI4-Lite Slave Monitor
class axi4_lite_slave_monitor extends uvm_monitor;

  // UVM Factory Registration
  `uvm_component_utils(axi4_lite_slave_monitor)

  // Virtual interface handle (using the SLAVE_MONITOR modport)
  virtual axi4_lite_slave_if vif;

  // Analysis port to send observed transactions to the scoreboard/subscribers
  uvm_analysis_port #(axi4_lite_master_seq_item) ap; // Using master_seq_item for simplicity of comparison

  // Constructor
  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  // Build Phase: Get the virtual interface and create analysis port
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    // Get the specific slave monitor clocking block modport
    if (!uvm_config_db #(virtual axi4_lite_slave_if)::get(this, "", "vif", vif)) begin
      `uvm_fatal(get_full_name(), "Virtual interface 'vif' not set for slave monitor")
    end
    ap = new("ap", this);
  endfunction

  // Run Phase: Main monitoring loop
  virtual task run_phase(uvm_phase phase);
    fork
      monitor_slave_writes();
      monitor_slave_reads();
    join_none
  endtask

  // Task to monitor AXI4-Lite write transactions from the slave's perspective
  virtual protected task monitor_slave_writes();
    axi4_lite_master_seq_item tr; // Re-using master item for consistency
    forever begin
      // Wait for AWVALID and WVALID to be asserted AND AWREADY/WREADY from slave
      @(vif.cb_slave_monitor); // Use slave monitor clocking block
      wait (vif.cb_slave_monitor.S_AWVALID && vif.cb_slave_monitor.S_WVALID && vif.cb_slave_monitor.S_AWREADY && vif.cb_slave_monitor.S_WREADY);

      tr = axi4_lite_master_seq_item::type_id::create("tr");
      tr.tr_type = axi4_lite_master_seq_item::WRITE;
      tr.addr    = vif.cb_slave_monitor.S_AWADDR;
      tr.wdata   = vif.cb_slave_monitor.S_WDATA;
      tr.wstrb   = vif.cb_slave_monitor.S_WSTRB;

      `uvm_info(get_full_name(), $sformatf("Observed Slave Write Transaction: addr=0x%0h, wdata=0x%0h", tr.addr, tr.wdata), UVM_HIGH)

      // Wait for BVALID from slave and BREADY from master
      @(vif.cb_slave_monitor); // Use slave monitor clocking block
      wait (vif.cb_slave_monitor.S_BVALID && vif.cb_slave_monitor.S_BREADY);
      tr.resp = vif.cb_slave_monitor.S_BRESP;

      `uvm_info(get_full_name(), $sformatf("Observed Slave Write Response: resp=0x%0h", tr.resp), UVM_HIGH)

      // Send the observed transaction
      ap.write(tr);
    end
  endtask

  // Task to monitor AXI4-Lite read transactions from the slave's perspective
  virtual protected task monitor_slave_reads();
    axi4_lite_master_seq_item tr; // Re-using master item for consistency
    forever begin
      // Wait for ARVALID to be asserted AND ARREADY from slave
      @(vif.cb_slave_monitor); // Use slave monitor clocking block
      wait (vif.cb_slave_monitor.S_ARVALID && vif.cb_slave_monitor.S_ARREADY);

      tr = axi4_lite_master_seq_item::type_id::create("tr");
      tr.tr_type = axi4_lite_master_seq_item::READ;
      tr.addr    = vif.cb_slave_monitor.S_ARADDR;

      `uvm_info(get_full_name(), $sformatf("Observed Slave Read Request: addr=0x%0h", tr.addr), UVM_HIGH)

      // Wait for RVALID from slave and RREADY from master
      @(vif.cb_slave_monitor); // Use slave monitor clocking block
      wait (vif.cb_slave_monitor.S_RVALID && vif.cb_slave_monitor.S_RREADY);
      tr.rdata = vif.cb_slave_monitor.S_RDATA;
      tr.resp  = vif.cb_slave_monitor.S_RRESP;

      `uvm_info(get_full_name(), $sformatf("Observed Slave Read Data: rdata=0x%0h, resp=0x%0h", tr.rdata, tr.resp), UVM_HIGH)

      // Send the observed transaction
      ap.write(tr);
    end
  endtask

endclass


// AXI4-Lite Scoreboard
class axi4_lite_scoreboard extends uvm_scoreboard;

  `uvm_component_utils(axi4_lite_scoreboard)

  // Analysis FIFOs to store transactions from monitors
  uvm_tlm_analysis_fifo #(axi4_lite_master_seq_item) master_fifo;
  uvm_tlm_analysis_fifo #(axi4_lite_master_seq_item) slave_fifo;

  // Local model of the DUT's registers
  // This should ideally match the DUT's internal register behavior
  logic [31:0] expected_register_model [32]; // Assuming 32 registers as per DUT

  // Constructor
  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  // Build Phase
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    master_fifo = new("master_fifo", this);
    slave_fifo  = new("slave_fifo", this);

    // Initialize the expected register model
    for (int i = 0; i < 32; i++) begin
      expected_register_model[i] = 32'h0;
    end
  endfunction

  // Connect Phase
  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    // Monitors will connect their analysis ports to these FIFOs
  endfunction

 // In axi4_lite_scoreboard class
virtual task run_phase(uvm_phase phase);
  axi4_lite_master_seq_item master_tr, slave_tr;
  forever begin
    // Always wait for the master transaction first (the expected behavior)
    master_fifo.get(master_tr);
    `uvm_info(get_full_name(), $sformatf("SCOREBOARD: Received master transaction: %s", master_tr.sprint()), UVM_HIGH)

    // Predict the expected behavior based on the master transaction
    case (master_tr.tr_type)
      axi4_lite_master_seq_item::WRITE: begin
        expected_register_model[master_tr.addr] = master_tr.wdata;
        `uvm_info(get_full_name(), $sformatf("SCOREBOARD: Predicted write to addr 0x%0h with data 0x%0h", master_tr.addr, master_tr.wdata), UVM_LOW)
      end
      axi4_lite_master_seq_item::READ: begin
        master_tr.rdata = expected_register_model[master_tr.addr]; // Predict read data from model
        `uvm_info(get_full_name(), $sformatf("SCOREBOARD: Predicted read from addr 0x%0h, expected data 0x%0h", master_tr.addr, master_tr.rdata), UVM_LOW)
      end
    endcase

    // Now, wait for the corresponding slave transaction (the actual DUT behavior)
    slave_fifo.get(slave_tr);
    `uvm_info(get_full_name(), $sformatf("SCOREBOARD: Received slave transaction: %s", slave_tr.sprint()), UVM_HIGH)

    // Compare the expected (master_tr) with the actual (slave_tr)
    compare_transactions(master_tr, slave_tr);

    // Clear the received transaction items for the next iteration
    master_tr = null;
    slave_tr  = null;
  end
endtask

  // Task to compare master (expected) and slave (actual) transactions
  virtual protected function void compare_transactions(axi4_lite_master_seq_item expected_tr, axi4_lite_master_seq_item actual_tr);
    if (expected_tr.tr_type != actual_tr.tr_type) begin
      `uvm_error(get_full_name(), $sformatf("MISMATCH: Transaction type. Expected %s, Actual %s", expected_tr.tr_type.name(), actual_tr.tr_type.name()))
      return;
    end

    if (expected_tr.addr != actual_tr.addr) begin
      `uvm_error(get_full_name(), $sformatf("MISMATCH: Address. Expected 0x%0h, Actual 0x%0h", expected_tr.addr, actual_tr.addr))
      return;
    end

    case (expected_tr.tr_type)
      axi4_lite_master_seq_item::WRITE: begin
        if (expected_tr.wdata != actual_tr.wdata) begin
          `uvm_error(get_full_name(), $sformatf("MISMATCH: Write Data. Expected 0x%0h, Actual 0x%0h", expected_tr.wdata, actual_tr.wdata))
        end
        if (expected_tr.wstrb != actual_tr.wstrb) begin
          `uvm_error(get_full_name(), $sformatf("MISMATCH: Write Strobe. Expected 0x%0h, Actual 0x%0h", expected_tr.wstrb, actual_tr.wstrb))
        end
        if (actual_tr.resp != 2'b00) begin // AXI4-Lite OKAY response is 2'b00
          `uvm_error(get_full_name(), $sformatf("MISMATCH: Write Response. Expected OKAY (2'b00), Actual 0x%0h", actual_tr.resp))
        end
      end
      axi4_lite_master_seq_item::READ: begin
        if (expected_tr.rdata != actual_tr.rdata) begin
          `uvm_error(get_full_name(), $sformatf("MISMATCH: Read Data. Expected 0x%0h, Actual 0x%0h", expected_tr.rdata, actual_tr.rdata))
        end
        if (actual_tr.resp != 2'b00) begin // AXI4-Lite OKAY response is 2'b00
          `uvm_error(get_full_name(), $sformatf("MISMATCH: Read Response. Expected OKAY (2'b00), Actual 0x%0h", actual_tr.resp))
        end
      end
    endcase

    `uvm_info(get_full_name(), $sformatf("MATCH: Transaction passed. Expected: %s, Actual: %s", expected_tr.sprint(), actual_tr.sprint()), UVM_LOW)
  endfunction

endclass


// AXI4-Lite Environment
class axi4_lite_env extends uvm_env;

  `uvm_component_utils(axi4_lite_env)

  // Agent and Scoreboard instances
  axi4_lite_master_agent m_agent;
  axi4_lite_slave_monitor s_monitor; // Slave monitor is part of the environment, not an agent
  axi4_lite_scoreboard   m_scoreboard;

  // Constructor
  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  // Build Phase
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    m_agent      = axi4_lite_master_agent::type_id::create("m_agent", this);
    s_monitor    = axi4_lite_slave_monitor::type_id::create("s_monitor", this);
    m_scoreboard = axi4_lite_scoreboard::type_id::create("m_scoreboard", this);
  endfunction

  // Connect Phase
  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    // Connect master agent's monitor to scoreboard's master FIFO
    m_agent.m_monitor.ap.connect(m_scoreboard.master_fifo.analysis_export);
    // Connect slave monitor to scoreboard's slave FIFO
    s_monitor.ap.connect(m_scoreboard.slave_fifo.analysis_export);
  endfunction

endclass


// Base Test Sequence
class base_test_sequence extends uvm_sequence #(axi4_lite_master_seq_item);

  `uvm_object_utils(base_test_sequence)

  // Constructor
  function new(string name = "base_test_sequence");
    super.new(name);
  endfunction

endclass


// AXI4-Lite Write/Read Test Sequence
class axi4_lite_write_read_test_sequence extends base_test_sequence;

  `uvm_object_utils(axi4_lite_write_read_test_sequence)

  // Constructor
  function new(string name = "axi4_lite_write_read_test_sequence");
    super.new(name);
  endfunction

  // Body task: Defines the sequence of transactions
  virtual task body();
    axi4_lite_master_seq_item req;
    bit [31:0] write_val;

    `uvm_info(get_full_name(), "Starting write/read test sequence...", UVM_LOW)

    // Loop through some addresses to write and then read
    for (int i = 0; i < 5; i++) begin
      // 1. Write Transaction
      req = axi4_lite_master_seq_item::type_id::create("req");
      start_item(req);
      req.tr_type = axi4_lite_master_seq_item::WRITE;
      req.addr    = i; // Write to address i
      req.wdata   = $urandom_range(32'hFFFF_FFFF, 32'h0000_0001); // Random data
      write_val   = req.wdata; // Store for later comparison
      finish_item(req);
      `uvm_info(get_full_name(), $sformatf("Sent WRITE transaction: addr=0x%0h, wdata=0x%0h", req.addr, req.wdata), UVM_HIGH)

      // 2. Read Transaction
      req = axi4_lite_master_seq_item::type_id::create("req");
      start_item(req);
      req.tr_type = axi4_lite_master_seq_item::READ;
      req.addr    = i; // Read from the same address
      finish_item(req);
      `uvm_info(get_full_name(), $sformatf("Sent READ transaction: addr=0x%0h, received rdata=0x%0h", req.addr, req.rdata), UVM_HIGH)

      // Basic check within sequence (scoreboard does full verification)
      if (req.rdata != write_val) begin
        `uvm_error(get_full_name(), $sformatf("READ DATA MISMATCH in sequence! Addr: 0x%0h, Expected: 0x%0h, Actual: 0x%0h", i, write_val, req.rdata))
      end else begin
        `uvm_info(get_full_name(), $sformatf("READ DATA MATCH in sequence! Addr: 0x%0h, Expected: 0x%0h, Actual: 0x%0h", i, write_val, req.rdata), UVM_HIGH)
      end
    end

    `uvm_info(get_full_name(), "Finished write/read test sequence.", UVM_LOW)
  endtask

endclass


// Base Test
class base_test extends uvm_test;

  `uvm_component_utils(base_test)

  // Environment instance
  axi4_lite_env env;

  // Constructor
  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  // Build Phase
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    env = axi4_lite_env::type_id::create("env", this);
  endfunction

  // End of Elaboration Phase: Check for fatal errors
  function void end_of_elaboration_phase(uvm_phase phase);
    super.end_of_elaboration_phase(phase);
    uvm_top.print_topology();
  endfunction

  // Report Phase: Print UVM report summary
  function void report_phase(uvm_phase phase);
    super.report_phase(phase);
    `uvm_info(get_full_name(), "UVM Test Completed. Check log for results.", UVM_LOW)
  endfunction

endclass


// AXI4-Lite Write/Read Test
class axi4_lite_write_read_test extends base_test;

  `uvm_component_utils(axi4_lite_write_read_test)

  // Constructor
  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  // Run Phase: Start the sequence
  virtual task run_phase(uvm_phase phase);
    axi4_lite_write_read_test_sequence seq;
    phase.raise_objection(this); // Raise objection to prevent test from ending prematurely
    seq = axi4_lite_write_read_test_sequence::type_id::create("seq");
    seq.start(env.m_agent.m_sequencer); // Start sequence on the master agent's sequencer
    #100ns; // Give some time for last transactions to complete
    phase.drop_objection(this); // Drop objection to allow test to end
  endtask

endclass


// Top-level Testbench Module
module top_tb;

  // Clock and Reset generation
  bit ACLK;
  bit ARESETN;

  // Clock generation
  always #5 ACLK = !ACLK; // 10ns period, 100MHz clock

  // Reset generation
  initial begin
    ACLK = 0;
    ARESETN = 0;
    #20; // Hold reset for 20ns (2 clock cycles)
    ARESETN = 1; // De-assert reset
    `uvm_info("TOP_TB", "Reset de-asserted", UVM_LOW)

    // Dump waveforms to a VCD file
    $dumpfile("dump.vcd"); // Specify the output file name
    // Explicitly dump signals from the DUT and the interface instance
    $dumpvars(0, top_tb.dut);   // Dump all signals within the DUT instance
    $dumpvars(0, top_tb.axi_if); // Dump all signals within the AXI interface instance
  end

  // Instantiate AXI4-Lite Interface
  axi4_lite_slave_if axi_if (.ACLK(ACLK), .ARESETN(ARESETN));

  // Instantiate DUT
  // The 'axi4_lite_slave' module is assumed to be in a separate file (e.g., axi4_lite_slave.sv)
  // and compiled alongside this testbench.
  axi4_lite_slave #(
    .DATA_WIDTH(axi_if.DATA_WIDTH),
    .ADDRESS(axi_if.ADDR_WIDTH)
  ) dut (
    .ACLK(axi_if.ACLK),
    .ARESETN(axi_if.ARESETN),

    .S_ARADDR(axi_if.S_ARADDR),
    .S_ARVALID(axi_if.S_ARVALID),
    .S_RREADY(axi_if.S_RREADY),

    .S_AWADDR(axi_if.S_AWADDR),
    .S_AWVALID(axi_if.S_AWVALID),
    .S_WDATA(axi_if.S_WDATA),
    .S_WSTRB(axi_if.S_WSTRB),
    .S_WVALID(axi_if.S_WVALID),
    .S_BREADY(axi_if.S_BREADY),

    .S_ARREADY(axi_if.S_ARREADY),
    .S_RDATA(axi_if.S_RDATA),
    .S_RRESP(axi_if.S_RRESP),
    .S_RVALID(axi_if.S_RVALID),
    .S_AWREADY(axi_if.S_AWREADY),
    .S_WREADY(axi_if.S_WREADY),
    .S_BRESP(axi_if.S_BRESP),
    .S_BVALID(axi_if.S_BVALID)
  );

  // Set virtual interface to UVM config_db
  initial begin
    // Set for master agent's driver and monitor
    uvm_config_db #(virtual axi4_lite_slave_if)::set(null, "uvm_test_top.env.m_agent.m_driver", "vif", axi_if.MASTER_DRIVER);
    uvm_config_db #(virtual axi4_lite_slave_if)::set(null, "uvm_test_top.env.m_agent.m_monitor", "vif", axi_if.MASTER_MONITOR);
    // Set for slave monitor
    uvm_config_db #(virtual axi4_lite_slave_if)::set(null, "uvm_test_top.env.s_monitor", "vif", axi_if.SLAVE_MONITOR);

    // Run the UVM test
    run_test("axi4_lite_write_read_test");
  end

endmodule
