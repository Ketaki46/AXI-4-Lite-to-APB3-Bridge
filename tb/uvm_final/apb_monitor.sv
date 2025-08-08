
class apb_monitor extends uvm_monitor;
  
  `uvm_component_utils(apb_monitor)
  
  virtual apb_interface vif;
  uvm_analysis_port #(apb_transaction) item_collected_port;
  
  apb_transaction trans_collected;

  function new(string name = "apb_monitor", uvm_component parent);
    super.new(name, parent);
    item_collected_port = new("item_collected_port", this);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    `uvm_info(get_type_name(), $sformatf("Entered build phase of APB_monitor"), UVM_NONE)
    uvm_config_db#(virtual apb_interface)::get(this, "", "apb_vif", vif);
      
  endfunction

  virtual task run_phase(uvm_phase phase);
    forever begin
      collect_transaction();
    end
  endtask


   virtual task collect_transaction();
     
    // APB FSM signals - Wait for SETUP phase
    @(vif.monitor_cb iff (vif.monitor_cb.psel && !vif.monitor_cb.penable));
    
    trans_collected = apb_transaction::type_id::create("trans_collected");
    trans_collected.addr = vif.monitor_cb.paddr;
    trans_collected.cmd = vif.monitor_cb.pwrite;
    trans_collected.psel = 1'b1;
    trans_collected.penable = 1'b0;
    
    if (vif.monitor_cb.pwrite) begin
      trans_collected.data = vif.monitor_cb.pwdata;
    end
    
    // Wait for ACCESS phase
    @(vif.monitor_cb iff (vif.monitor_cb.psel && vif.monitor_cb.penable));
    trans_collected.penable = 1'b1;
    
    // Wait for PREADY
    @(vif.monitor_cb iff vif.monitor_cb.pready);
    trans_collected.pready = 1'b1;
    trans_collected.slverr = vif.monitor_cb.pslverr;
    
    if (!vif.monitor_cb.pwrite) begin
      trans_collected.rdata = vif.monitor_cb.prdata;
    end
    
    `uvm_info(get_type_name(), $sformatf("APB Monitor: %s", trans_collected.convert2string()), UVM_MEDIUM)
    item_collected_port.write(trans_collected);
  endtask
  


endclass
