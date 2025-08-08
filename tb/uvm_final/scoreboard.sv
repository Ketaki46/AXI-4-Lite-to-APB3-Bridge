`uvm_analysis_imp_decl(_axi)
`uvm_analysis_imp_decl(_apb)

class scoreboard extends uvm_scoreboard;
  
  `uvm_component_utils(scoreboard)
  
  uvm_analysis_imp_axi #(axi_transaction, scoreboard) axi_imp;
  uvm_analysis_imp_apb #(apb_transaction, scoreboard) apb_imp;
  
  // Memory model for data integrity check
  bit [31:0] memory [bit [31:0]];
  
  // Transaction queues for correlation
  axi_transaction axi_write_q[$];
  axi_transaction axi_read_q[$];

  // ADDED: Separate pending queues for writes and reads
  axi_transaction pending_axi_write_queue[$];
  axi_transaction pending_axi_read_queue[$];
  
  
  int axi_write_count = 0;
  int axi_read_count = 0;
  int apb_write_count = 0;
  int apb_read_count = 0;
  
  function new(string name = "scoreboard", uvm_component parent);
    super.new(name, parent);
    axi_imp = new("axi_imp", this);
    apb_imp = new("apb_imp", this);
  endfunction

 
  function void write_axi(axi_transaction axi_txn);
    if (axi_txn.cmd) begin // Write transaction
      pending_axi_write_queue.push_back(axi_txn);
      axi_write_count++;
      memory[axi_txn.addr] = axi_txn.data;
      `uvm_info("scoreboard", $sformatf("Received AXI WRITE #%0d: addr=0x%0x data=0x%0x", axi_write_count, axi_txn.addr, axi_txn.data), UVM_MEDIUM)
      
    end else begin // Read transaction
      pending_axi_read_queue.push_back(axi_txn);
      axi_read_count++;
      `uvm_info("scoreboard", $sformatf("Received AXI READ #%0d: addr=0x%0x", axi_read_count, axi_txn.addr), UVM_MEDIUM)
      check_read_data_integrity(axi_txn);
    end
  endfunction

  
  function void write_apb(apb_transaction apb_txn);
    if (apb_txn.cmd) begin // APB Write
      apb_write_count++;
      handle_apb_write(apb_txn);
    end else begin // APB Read  
      apb_read_count++;
      handle_apb_read(apb_txn);
    end
  endfunction


  function void handle_apb_write(apb_transaction apb_txn);
    axi_transaction matching_axi;
    bit found = 0;
    for (int i = 0; i < pending_axi_write_queue.size(); i++) begin
      if (pending_axi_write_queue[i].addr == apb_txn.addr) begin
        matching_axi = pending_axi_write_queue[i];
        pending_axi_write_queue.delete(i);
        found = 1;
        break;
      end
    end
    
    if (found) begin
      if (matching_axi.data == apb_txn.data) begin
        
        `uvm_info("SCOREBOARD", $sformatf("**Write correlation successful** MATCH !!!!!!! : addr=0x%0x data=0x%0x, APB pkt : addr=0x%0x data=0x%0x", matching_axi.addr, matching_axi.data, apb_txn.addr, apb_txn.data), UVM_MEDIUM)
        
      end else begin
        `uvm_error("SCOREBOARD", $sformatf("Write data mismatch: addr=0x%0x AXI=0x%0x, APB=0x%0x", apb_txn.addr, matching_axi.data, apb_txn.data))
      end
      
      // Check error propagation
      if (apb_txn.slverr && matching_axi.resp != 2'b10) begin
        `uvm_error("SCOREBOARD", "APB slave error not properly propagated to AXI write response")
      end
    end else begin
      `uvm_error("SCOREBOARD", $sformatf("APB write without corresponding AXI write: addr=0x%0x data=0x%0x", apb_txn.addr, apb_txn.data))
    end
  endfunction

  // **********Handle APB read transactions************
  function void handle_apb_read(apb_transaction apb_txn);
    axi_transaction matching_axi;
    bit found = 0;
    
    // Search for matching AXI read transaction by address
    for (int i = 0; i < pending_axi_read_queue.size(); i++) begin
      if (pending_axi_read_queue[i].addr == apb_txn.addr) begin
        matching_axi = pending_axi_read_queue[i];
        pending_axi_read_queue.delete(i);
        found = 1;
        break;
      end
    end
    
    if (found) begin
      
      if (matching_axi.rdata == apb_txn.rdata) begin
        
        `uvm_info("SCOREBOARD", $sformatf("**Read correlation successful** MATCH !!!!!!! : AXI pkt : addr=0x%0x rdata=0x%0x, APB pkt : addr=0x%0x rdata=0x%0x", matching_axi.addr, matching_axi.rdata, apb_txn.addr, apb_txn.rdata), UVM_MEDIUM)
        
      end else begin
        `uvm_error("SCOREBOARD", $sformatf("Read data mismatch: addr=0x%0x AXI=0x%0x, APB=0x%0x", apb_txn.addr, matching_axi.rdata, apb_txn.rdata))
      end
      
//       // Check error propagation
//       if (apb_txn.slverr && matching_axi.resp != 2'b10) begin
//         `uvm_error("SCOREBOARD", "APB slave error not properly propagated to AXI read response")
//       end
      
    end else begin
      `uvm_error("SCOREBOARD", $sformatf("APB read without corresponding AXI read: addr=0x%0x rdata=0x%0x", apb_txn.addr, apb_txn.rdata))
    end
  endfunction

  virtual function void check_read_data_integrity(axi_transaction trans);
    if (memory.exists(trans.addr)) begin
      if (memory[trans.addr] !== trans.rdata) begin
        `uvm_error("DATA_INTEGRITY", $sformatf("Read data mismatch at addr 0x%0h: expected=0x%0h, actual=0x%0h", trans.addr, memory[trans.addr], trans.rdata))
      end else begin
        `uvm_info("DATA_INTEGRITY", $sformatf("Read data verified at addr 0x%0h: data=0x%0h", trans.addr, trans.rdata), UVM_MEDIUM)
      end
    end else begin
      `uvm_warning("DATA_INTEGRITY", $sformatf("Reading from unwritten address 0x%0h", trans.addr))
    end
  endfunction

  // NEW: Debug function to print queue status
  virtual function void print_queue_status();
    `uvm_info("SCOREBOARD", $sformatf("Queue Status: Pending AXI Writes=%0d, Pending AXI Reads=%0d", pending_axi_write_queue.size(), pending_axi_read_queue.size()), UVM_HIGH)
    `uvm_info("SCOREBOARD", $sformatf("Transaction Counts: AXI_W=%0d, AXI_R=%0d, APB_W=%0d, APB_R=%0d", axi_write_count, axi_read_count, apb_write_count, apb_read_count), UVM_HIGH)
  endfunction

  virtual function void report_phase(uvm_phase phase);
    super.report_phase(phase);

    if (pending_axi_write_queue.size() > 0) begin
      `uvm_warning("SCOREBOARD", $sformatf("%0d unmatched AXI write transactions", pending_axi_write_queue.size()))
    end
    
    if (pending_axi_read_queue.size() > 0) begin
      `uvm_warning("SCOREBOARD", $sformatf("%0d unmatched AXI read transactions", pending_axi_read_queue.size()))
    end

    if (axi_write_q.size() > 0) begin
      `uvm_warning("SCOREBOARD", $sformatf("%0d unmatched AXI write transactions in legacy queue", axi_write_q.size()))
    end
    
    if (axi_read_q.size() > 0) begin
      `uvm_warning("SCOREBOARD", $sformatf("%0d unmatched AXI read transactions in legacy queue", axi_read_q.size()))
    end

    if (pending_axi_write_queue.size() == 0 && pending_axi_read_queue.size() == 0) begin
      `uvm_info(get_type_name(), "✓ ALL TRANSACTIONS SUCCESSFULLY CORRELATED!", UVM_LOW)
    end

  endfunction

endclass

class axi_protocol_checker extends uvm_component;
  
  `uvm_component_utils(axi_protocol_checker)

  virtual axi_interface vif;

  function new(string name = "axi_protocol_checker", uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual axi_interface)::get(this, "", "axi_vif", vif))
      `uvm_error("NO VIF", "Virtual interface must be set")
  endfunction

  virtual task run_phase(uvm_phase phase);
    fork
      check_axi_protocol_rules();
    join
  endtask

  virtual task check_axi_protocol_rules();
    forever begin
      @(posedge vif.clk);
      check_valid_ready_handshake();
    end
  endtask

  virtual function void check_valid_ready_handshake();
    static bit awvalid_prev = 0;
    static bit arvalid_prev = 0;
    static bit wvalid_prev = 0;
    
    awvalid_prev = vif.awvalid;
    arvalid_prev = vif.arvalid;
    wvalid_prev = vif.wvalid;
    
    // Check that VALID doesn't go low until READY is asserted
    if (awvalid_prev && !vif.awvalid && !vif.awready) begin
      `uvm_error("AXI_PROTOCOL", "AWVALID went low before AWREADY was asserted")
    end
    
    if (arvalid_prev && !vif.arvalid && !vif.arready) begin
      `uvm_error("AXI_PROTOCOL", "ARVALID went low before ARREADY was asserted")
    end
    
    if (wvalid_prev && !vif.wvalid && !vif.wready) begin
      `uvm_error("AXI_PROTOCOL", "WVALID went low before WREADY was asserted")
    end
  endfunction

endclass
    
class apb_protocol_checker extends uvm_component;
  
  `uvm_component_utils(apb_protocol_checker)
  
  virtual apb_interface vif;
  
  typedef enum {APB_IDLE, APB_SETUP, APB_ACCESS} apb_state_t;
  apb_state_t current_state;

  function new(string name = "apb_protocol_checker", uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual apb_interface)::get(this, "", "apb_vif", vif))
      `uvm_error("NO VIF", "Virtual interface must be set")
    current_state = APB_IDLE;
  endfunction

  virtual task run_phase(uvm_phase phase);
    fork
      check_apb_protocol_rules();
      track_apb_state_machine();
    join
  endtask

  virtual task track_apb_state_machine();
    forever begin
      @(posedge vif.clk);
      
      case (current_state)
        APB_IDLE: begin
          if (vif.psel) begin
            current_state = APB_SETUP;
            check_setup_phase();
          end
        end
        
        APB_SETUP: begin
          if (vif.penable) begin
            current_state = APB_ACCESS;
            check_access_phase();
          end else if (!vif.psel) begin
            current_state = APB_IDLE;
            `uvm_error("APB_PROTOCOL", "PSEL deasserted during SETUP phase")
          end
        end
        
        APB_ACCESS: begin
          if (vif.pready) begin
            current_state = vif.psel ? APB_SETUP : APB_IDLE;
          end else if (!vif.psel || !vif.penable) begin
            current_state = APB_IDLE;
            `uvm_error("APB_PROTOCOL", "PSEL or PENABLE deasserted during ACCESS phase")
          end
        end
      endcase
    end
  endtask

  virtual function void check_setup_phase();
    if (vif.penable) begin
      `uvm_error("APB_PROTOCOL", "PENABLE should be low during SETUP phase")
    end
    
    if (vif.pwrite && $isunknown(vif.pwdata)) begin
      `uvm_error("APB_PROTOCOL", "PWDATA has unknown values during write SETUP")
    end
    
    if ($isunknown(vif.paddr)) begin
      `uvm_error("APB_PROTOCOL", "PADDR has unknown values during SETUP")
    end
  endfunction

  virtual function void check_access_phase();
    if (!vif.psel) begin
      `uvm_error("APB_PROTOCOL", "PSEL must remain high during ACCESS phase")
    end
    
    if (!vif.penable) begin
      `uvm_error("APB_PROTOCOL", "PENABLE must be high during ACCESS phase")
    end
  endfunction

  virtual task check_apb_protocol_rules();
    forever begin
      @(posedge vif.clk);
      
      if ($isunknown(vif.psel)) begin
        `uvm_error("APB_PROTOCOL", "PSEL has unknown value")
      end
      
      if ($isunknown(vif.penable)) begin
        `uvm_error("APB_PROTOCOL", "PENABLE has unknown value")
      end
      
      if (vif.psel && $isunknown(vif.pwrite)) begin
        `uvm_error("APB_PROTOCOL", "PWRITE has unknown value when PSEL is high")
      end
    end
  endtask

endclass
