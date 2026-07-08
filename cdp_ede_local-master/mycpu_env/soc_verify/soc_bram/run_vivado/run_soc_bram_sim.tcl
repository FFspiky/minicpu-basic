set script_dir [file normalize [file dirname [info script]]]
cd $script_dir

source ./create_project.tcl
update_compile_order -fileset sources_1
update_compile_order -fileset sim_1
set_property top tb_top [get_filesets sim_1]
launch_simulation -simset sim_1 -mode behavioral
run all
quit
