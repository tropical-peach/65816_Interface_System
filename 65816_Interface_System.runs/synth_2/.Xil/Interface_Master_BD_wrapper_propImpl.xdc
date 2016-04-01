set_property SRC_FILE_INFO {cfile:/home/steven/Desktop/65816_Interface_System/65816_Interface_System.srcs/sources_1/bd/Interface_Master_BD/ip/Interface_Master_BD_processing_system7_0_0/Interface_Master_BD_processing_system7_0_0.xdc rfile:../../../65816_Interface_System.srcs/sources_1/bd/Interface_Master_BD/ip/Interface_Master_BD_processing_system7_0_0/Interface_Master_BD_processing_system7_0_0.xdc id:1 order:EARLY scoped_inst:Interface_Master_BD_i/processing_system7_0/inst} [current_design]
set_property SRC_FILE_INFO {cfile:/home/steven/Desktop/65816_Interface_System/65816_Interface_System.srcs/sources_1/bd/Interface_Master_BD/ip/Interface_Master_BD_clk_wiz_0_0/Interface_Master_BD_clk_wiz_0_0.xdc rfile:../../../65816_Interface_System.srcs/sources_1/bd/Interface_Master_BD/ip/Interface_Master_BD_clk_wiz_0_0/Interface_Master_BD_clk_wiz_0_0.xdc id:2 order:EARLY scoped_inst:Interface_Master_BD_i/clk_wiz_0/U0} [current_design]
set_property SRC_FILE_INFO {cfile:/home/steven/Desktop/65816_Interface_System/65816_Interface_System.srcs/constrs_1/imports/65816_Interface_System/ZYBO_Master.xdc rfile:../../../65816_Interface_System.srcs/constrs_1/imports/65816_Interface_System/ZYBO_Master.xdc id:3} [current_design]
set_property src_info {type:SCOPED_XDC file:1 line:21 export:INPUT save:INPUT read:READ} [current_design]
set_input_jitter clk_fpga_2 2.44614
set_property src_info {type:SCOPED_XDC file:1 line:24 export:INPUT save:INPUT read:READ} [current_design]
set_input_jitter clk_fpga_1 0.19998
set_property src_info {type:SCOPED_XDC file:1 line:27 export:INPUT save:INPUT read:READ} [current_design]
set_input_jitter clk_fpga_0 0.3
set_property src_info {type:SCOPED_XDC file:2 line:56 export:INPUT save:INPUT read:READ} [current_design]
set_input_jitter [get_clocks -of_objects [get_ports clk_in1]] 0.1
set_property src_info {type:XDC file:3 line:20 export:INPUT save:INPUT read:READ} [current_design]
set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets reset_65816_module_IBUF]
