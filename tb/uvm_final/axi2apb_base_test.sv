
//1. basic_sequence

class axi2apb_base_test extends uvm_test;
  
 
  `uvm_component_utils(axi2apb_base_test)
  
  axi2apb_env env;

  function new(string name = "axi2apb_base_test", uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    env = axi2apb_env::type_id::create("env", this);
  endfunction

  virtual function void end_of_elaboration_phase(uvm_phase phase);
    uvm_top.print_topology();
  endfunction

  virtual task run_phase(uvm_phase phase);
    phase.raise_objection(this);
    
    `uvm_info(get_type_name(), "Test Started", UVM_NONE)
    
    run_basic_test();        // task
    
    #100ns;
    
    `uvm_info(get_type_name(), "Test Completed", UVM_NONE)
    phase.drop_objection(this);
  endtask

  virtual task run_basic_test();
    basic_sequence seq;								// axi_sequence.sv
    seq = basic_sequence::type_id::create("seq");
    seq.start(env.axi_agent1.sequencer); //5 write & 5 read
  endtask

endclass

//2. Error sequence
class axi2apb_error_test extends axi2apb_base_test;
  
  `uvm_component_utils(axi2apb_error_test)

  function new(string name = "axi2apb_error_test", uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual task run_basic_test();
    error_injection_sequence seq;
    seq = error_injection_sequence::type_id::create("seq");
    seq.start(env.axi_agent1.sequencer);
  endtask

endclass

// 3. Reset sequence 
class axi2apb_reset_test extends axi2apb_base_test;
  
  `uvm_component_utils(axi2apb_reset_test)

  function new(string name = "axi2apb_reset_test", uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual task run_basic_test();
    reset_sequence seq;
    seq = reset_sequence::type_id::create("seq");
    seq.start(env.axi_agent1.sequencer);
  endtask

endclass


