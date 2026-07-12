set script_dir [file normalize [file dirname [info script]]]
cd $script_dir

source ./create_board_project.tcl

set_property top soc_lite_lcd_top [get_filesets sources_1]
set_property top tb_lcd_top [get_filesets sim_1]
set_property verilog_define {} [get_filesets sim_1]
update_compile_order -fileset sources_1
update_compile_order -fileset sim_1

if {[llength [get_runs -quiet impl_1]] > 0} {
    reset_run impl_1
}
if {[llength [get_runs -quiet synth_1]] > 0} {
    reset_run synth_1
}

close_project
puts "PASS: final_cpu_lcd GUI project refreshed; synth_1 and impl_1 are reset"
quit
