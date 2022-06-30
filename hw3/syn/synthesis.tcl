# You can only modify "cycle" and "read files"
set cycle 1.67
read_file -format verilog { ../hdl/lenet.v  }
#read_file -format verilog { ../hdl/fsm.v  }
#read_file -format verilog { ../hdl/addr_ctl.v  }
#read_file -format verilog { ../hdl/pe.v  }
#read_file -format verilog { ../hdl/actquant.v  }

source compile.tcl