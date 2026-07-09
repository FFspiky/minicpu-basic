set script_dir [file normalize [file dirname [info script]]]
cd $script_dir

set project_file ./project_lcd/loongson_bram_lcd.xpr
if {![file exists $project_file]} {
    error "BRAM LCD project not found: $project_file"
}

open_project $project_file

set report_dir [file join $script_dir reports]
file mkdir $report_dir

if {[catch {open_run impl_1} err]} {
    error "Cannot open impl_1 for timing reports: $err"
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
quit
