set script_dir [file normalize [file dirname [info script]]]
cd $script_dir

source ./create_board_project.tcl

set_property top tb_lcd_top [get_filesets sim_1]
if {[info exists ::env(GAME_SIM_FAST)] && $::env(GAME_SIM_FAST) ne "" &&
    $::env(GAME_SIM_FAST) ne "0"} {
    set_property verilog_define GAME_SIM_FAST [get_filesets sim_1]
} else {
    set_property verilog_define {} [get_filesets sim_1]
}
launch_simulation -simset sim_1 -mode behavioral
run all
quit
