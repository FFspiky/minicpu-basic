set script_dir [file normalize [file dirname [info script]]]
set run_dir [file dirname $script_dir]
cd $run_dir

source ./create_board_project.tcl
set simset [get_filesets sim_1]
set previous_top [get_property TOP $simset]
set_property TOP tb_generic_c_runtime $simset
update_compile_order -fileset sim_1

# The generic application MIF is produced by Studio's C build and is loaded
# by the behavioral unified RAM from this repository-relative path.
set sim_work [file normalize [file join $run_dir project_lcd final_cpu_lcd.sim sim_1 behav xsim]]
set sim_mif_dir [file join $sim_work tools la32asm build]
file mkdir $sim_mif_dir
file copy -force [file normalize [file join $run_dir .. tools la32asm build playground.mif]] \
                 [file join $sim_mif_dir playground.mif]

if {[catch {
    launch_simulation -simset sim_1 -mode behavioral
    run all
} error_message options]} {
    catch {close_sim -quiet}
    set_property TOP $previous_top $simset
    close_project
    return -options $options $error_message
}

close_sim
set_property TOP $previous_top $simset
close_project
puts "GENERIC_C_RUNTIME_SIM_PASS"
