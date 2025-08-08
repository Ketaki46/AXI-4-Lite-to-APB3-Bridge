class apb_transaction extends uvm_sequence_item;
  
  bit [31:0] addr;
  bit [31:0] data;
  bit        cmd;        // 0: read, 1: write
  bit [31:0] rdata;
  bit        slverr;
  
  bit        psel;
  bit        penable;
  bit        pready;

  `uvm_object_utils_begin(apb_transaction)
    `uvm_field_int(addr, UVM_ALL_ON)
    `uvm_field_int(data, UVM_ALL_ON)
    `uvm_field_int(cmd, UVM_ALL_ON)
    `uvm_field_int(rdata, UVM_ALL_ON)
    `uvm_field_int(slverr, UVM_ALL_ON)
  `uvm_object_utils_end

  function new(string name = "apb_transaction");
    super.new(name);
  endfunction

  virtual function string convert2string();
    return $sformatf("APB: cmd=%0s addr=0x%0h data=0x%0h slverr=%0b", 
                     cmd ? "WRITE" : "READ", addr, data, slverr);
  endfunction

endclass
