set script_dir [file normalize [file dirname [info script]]]
cd $script_dir

source ./create_board_project.tcl

launch_runs synth_1 -jobs 8
wait_on_run synth_1

if {[get_property PROGRESS [get_runs synth_1]] != "100%"} {
    error "synth_1 did not finish"
}
if {[get_property STATUS [get_runs synth_1]] != "synth_design Complete!"} {
    error "synth_1 failed: [get_property STATUS [get_runs synth_1]]"
}

launch_runs impl_1 -to_step write_bitstream -jobs 8
wait_on_run impl_1

if {[get_property PROGRESS [get_runs impl_1]] != "100%"} {
    error "impl_1 did not finish"
}
if {[string first "Complete!" [get_property STATUS [get_runs impl_1]]] < 0} {
    error "impl_1 failed: [get_property STATUS [get_runs impl_1]]"
}

quit
