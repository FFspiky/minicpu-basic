# Capture stable references outside the resettable run directories.
# Run this only after the generated bitstream has passed board testing.
set script_dir [file normalize [file dirname [info script]]]
set project_file [file join $script_dir project_lcd final_cpu_lcd.xpr]
if {[current_project -quiet] eq ""} {
    open_project $project_file
}

foreach run_name {synth_1 impl_1} {
    if {[llength [get_runs -quiet $run_name]] != 1} {
        error "Missing run $run_name"
    }
    if {[string first "Complete!" [get_property STATUS [get_runs $run_name]]] < 0} {
        error "$run_name is not complete: [get_property STATUS [get_runs $run_name]]"
    }
}
if {[string first "write_bitstream Complete!" [get_property STATUS [get_runs impl_1]]] < 0} {
    error "impl_1 has not completed write_bitstream"
}

set checkpoint_dir [file join $script_dir checkpoints]
file mkdir $checkpoint_dir
open_run synth_1
write_checkpoint -force [file join $checkpoint_dir stable_synth.dcp]
close_design
open_run impl_1
write_checkpoint -force [file join $checkpoint_dir stable_routed.dcp]

set metadata [open [file join $checkpoint_dir baseline.txt] w]
puts $metadata "captured=[clock format [clock seconds] -format {%Y-%m-%d %H:%M:%S}]"
puts $metadata "part=[get_property PART [current_project]]"
puts $metadata "synth_status=[get_property STATUS [get_runs synth_1]]"
puts $metadata "impl_status=[get_property STATUS [get_runs impl_1]]"
close $metadata
puts "BASELINE_CAPTURED: $checkpoint_dir"
