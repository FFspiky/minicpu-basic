set script_dir [file normalize [file dirname [info script]]]
cd $script_dir

source ./create_board_project.tcl

set_property top tb_lcd_top [get_filesets sim_1]
launch_simulation -simset sim_1 -mode behavioral
run all
quit
