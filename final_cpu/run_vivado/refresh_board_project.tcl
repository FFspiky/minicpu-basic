set script_dir [file normalize [file dirname [info script]]]
cd $script_dir

source ./create_board_project.tcl

set_property top soc_lite_lcd_top [get_filesets sources_1]
set_property top tb_lcd_top [get_filesets sim_1]
set_property verilog_define {} [get_filesets sim_1]
update_compile_order -fileset sources_1
update_compile_order -fileset sim_1

close_project
puts "PASS: final_cpu_lcd GUI project refreshed; existing run products preserved"
quit
