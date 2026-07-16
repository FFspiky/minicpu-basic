set script_dir [file normalize [file dirname [info script]]]
cd $script_dir

# An alternate project directory allows a batch trace run while the default
# GUI project is open.  Normal invocations continue to use ./project.
if {[info exists ::env(CPU1234_SIM_PROJECT_DIR)]} {
    set project_dir [file normalize $::env(CPU1234_SIM_PROJECT_DIR)]
} else {
    set project_dir [file normalize [file join $script_dir project_trace_minimal_15]]
}
source ./create_project.tcl
update_compile_order -fileset sources_1
update_compile_order -fileset sim_1
set_property top tb_top [get_filesets sim_1]
launch_simulation -simset sim_1 -mode behavioral

# Vivado creates a default wave configuration containing top-level testbench
# objects.  Remove it before constructing the trace-only view below.
set default_waves [get_waves -quiet *]
if {[llength $default_waves] != 0} {
    remove_wave $default_waves
}

# The waveform contains exactly the fifteen requested trace signals.
set cpu_signals [list \
    /tb_top/debug_wb_pc \
    /tb_top/debug_wb_rf_we \
    /tb_top/debug_wb_rf_wnum \
    /tb_top/debug_wb_rf_wdata \
    /tb_top/debug_commit_inst]

set timing_signals [list \
    /tb_top/resetn \
    /tb_top/clk \
    /tb_top/soc_clk]

set compare_signals [list \
    /tb_top/trace_cmp_flag \
    /tb_top/ref_wb_pc \
    /tb_top/ref_wb_rf_wnum \
    /tb_top/ref_wb_rf_wdata \
    /tb_top/ref_wb_inst \
    /tb_top/debug_wb_rf_wdata_v \
    /tb_top/ref_wb_rf_wdata_v]

set wave_groups [list \
    TIMING $timing_signals \
    CPU_WRITEBACK $cpu_signals \
    REFERENCE_COMPARE $compare_signals]

set vcd_signals [concat $timing_signals $cpu_signals $compare_signals]

set vcd_path [file normalize [file join $script_dir trace_wave.vcd]]
file delete -force $vcd_path
open_vcd $vcd_path

set added_signal_count 0
foreach {group_name signal_paths} $wave_groups {
    add_wave_divider $group_name
    foreach signal_path $signal_paths {
        set signal_objects [get_objects -quiet $signal_path]
        if {[llength $signal_objects] == 0} {
            puts "WARNING: trace waveform signal not found: $signal_path"
        } else {
            add_wave -radix hex $signal_objects
            log_wave $signal_objects
            incr added_signal_count
        }
    }
}

if {$added_signal_count != 15} {
    error "Expected exactly 15 waveform signals, added $added_signal_count"
}
puts "Minimal waveform signal count: $added_signal_count"

foreach signal_path $vcd_signals {
    set signal_objects [get_objects -quiet $signal_path]
    if {[llength $signal_objects] != 0} {
        log_vcd $signal_objects
    }
}

run all
close_vcd
puts "Trace-focused VCD: $vcd_path"
quit
