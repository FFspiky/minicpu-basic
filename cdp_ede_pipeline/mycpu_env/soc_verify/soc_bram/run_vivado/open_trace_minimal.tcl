set script_dir [file normalize [file dirname [info script]]]
set wdb_path [file normalize [file join $script_dir \
    project_trace_minimal_15 loongson.sim sim_1 behav xsim tb_top_behav.wdb]]

if {![file exists $wdb_path]} {
    error "Minimal trace waveform database not found: $wdb_path"
}

open_wave_database $wdb_path

set default_waves [get_waves -quiet *]
if {[llength $default_waves] != 0} {
    remove_wave $default_waves
}

set timing_signals [list \
    /tb_top/resetn \
    /tb_top/clk \
    /tb_top/soc_clk]

set cpu_signals [list \
    /tb_top/debug_wb_pc \
    /tb_top/debug_wb_rf_we \
    /tb_top/debug_wb_rf_wnum \
    /tb_top/debug_wb_rf_wdata \
    /tb_top/debug_commit_inst]

set compare_signals [list \
    /tb_top/trace_cmp_flag \
    /tb_top/ref_wb_pc \
    /tb_top/ref_wb_rf_wnum \
    /tb_top/ref_wb_rf_wdata \
    /tb_top/ref_wb_inst \
    /tb_top/debug_wb_rf_wdata_v \
    /tb_top/ref_wb_rf_wdata_v]

set added_signal_count 0
foreach {group_name signal_paths} [list \
    TIMING $timing_signals \
    CPU_WRITEBACK $cpu_signals \
    REFERENCE_COMPARE $compare_signals] {
    add_wave_divider $group_name
    foreach signal_path $signal_paths {
        set signal_object [get_objects -quiet $signal_path]
        if {[llength $signal_object] != 0} {
            add_wave -radix hex $signal_object
            incr added_signal_count
        }
    }
}

if {$added_signal_count != 15} {
    error "Expected exactly 15 waveform signals, added $added_signal_count"
}
puts "Minimal waveform signal count: $added_signal_count"
puts "Opened minimal CPU/reference trace waveform: $wdb_path"
