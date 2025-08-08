class apb_agent extends uvm_agent;
  
  `uvm_component_utils(apb_agent)
  
  apb_monitor monitor;

  function new(string name = "apb_agent", uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    `uvm_info(get_type_name(), $sformatf("Entered build phase of APB_agent"), UVM_NONE)

    monitor = apb_monitor::type_id::create("monitor", this);
  endfunction

endclass
