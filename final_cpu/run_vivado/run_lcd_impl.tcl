set script_dir [file normalize [file dirname [info script]]]
cd $script_dir

source ./create_board_project.tcl

set vivado_jobs 4
if {[info exists ::env(VIVADO_JOBS)] && $::env(VIVADO_JOBS) ne ""} {
    set vivado_jobs $::env(VIVADO_JOBS)
}
if {![string is integer -strict $vivado_jobs] || $vivado_jobs < 1} {
    error "VIVADO_JOBS must be a positive integer"
}
puts "INFO: using $vivado_jobs Vivado job(s)"

proc reset_existing_run {run_name} {
    set runs [get_runs -quiet $run_name]
    if {[llength $runs] == 0} {
        return
    }
    puts "INFO: resetting $run_name before launch"
    reset_run $run_name
}

proc write_timing_reports {script_dir} {
    set report_dir [file join $script_dir reports]
    file mkdir $report_dir

    if {[catch {open_run impl_1} err]} {
        puts "WARNING: cannot open impl_1 for timing reports: $err"
        return
    }

    report_timing_summary \
        -delay_type max \
        -report_unconstrained \
        -check_timing_verbose \
        -file [file join $report_dir timing_summary.rpt]

    report_timing \
        -delay_type max \
        -sort_by group \
        -max_paths 20 \
        -nworst 1 \
        -file [file join $report_dir timing_worst_20.rpt]

    puts "Timing reports written to $report_dir"
}

reset_existing_run impl_1
reset_existing_run synth_1

launch_runs synth_1 -jobs $vivado_jobs
wait_on_run synth_1

if {[get_property PROGRESS [get_runs synth_1]] != "100%"} {
    error "synth_1 did not finish"
}
if {[get_property STATUS [get_runs synth_1]] != "synth_design Complete!"} {
    error "synth_1 failed: [get_property STATUS [get_runs synth_1]]"
}

set impl_failed 0
if {[catch {
    launch_runs impl_1 -to_step write_bitstream -jobs $vivado_jobs
    wait_on_run impl_1
} err]} {
    puts "WARNING: impl_1 launch/wait failed: $err"
    set impl_failed 1
}

if {[get_property PROGRESS [get_runs impl_1]] != "100%"} {
    puts "WARNING: impl_1 did not finish"
    set impl_failed 1
}
if {[string first "Complete!" [get_property STATUS [get_runs impl_1]]] < 0} {
    puts "WARNING: impl_1 status: [get_property STATUS [get_runs impl_1]]"
    set impl_failed 1
}

write_timing_reports $script_dir

if {$impl_failed} {
    error "impl_1 failed or did not complete cleanly"
}

quit
