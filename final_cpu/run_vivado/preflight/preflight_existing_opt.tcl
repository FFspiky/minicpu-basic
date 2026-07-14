set script_dir [file dirname [file normalize [info script]]]
set project_dir [file normalize [file join $script_dir .. project_lcd]]
set checkpoint [file join $project_dir final_cpu_lcd.runs impl_1 soc_lite_lcd_top_opt.dcp]
set report_dir [file join $script_dir reports_existing_opt]

file mkdir $report_dir

if {![file exists $checkpoint]} {
    error "Optimized checkpoint not found: $checkpoint"
}

open_checkpoint $checkpoint

set summary_file [file join $report_dir design_summary.txt]
set out [open $summary_file w]
puts $out "PART=[get_property PART [current_design]]"
puts $out "TOP=[get_property TOP [current_design]]"
puts $out "\nCLOCKS"
foreach c [get_clocks -quiet] {
    puts $out "[get_property NAME $c] period=[get_property PERIOD $c] source_pins=[get_property SOURCE_PINS $c]"
}

puts $out "\nTOP PORT LOCATIONS"
foreach p [lsort [get_ports -quiet]] {
    puts $out [format "%-24s PACKAGE_PIN=%-8s LOC=%-16s IOSTANDARD=%s" \
        [get_property NAME $p] \
        [get_property PACKAGE_PIN $p] \
        [get_property LOC $p] \
        [get_property IOSTANDARD $p]]
}

puts $out "\nCLOCK INPUT PATH"
foreach cell [get_cells -hier -quiet -filter {REF_NAME =~ IBUF* || REF_NAME =~ BUFG* || REF_NAME =~ PLLE2*}] {
    puts $out "CELL [get_property NAME $cell] REF=[get_property REF_NAME $cell] LOC=[get_property LOC $cell]"
    foreach pin [get_pins -quiet -of_objects $cell] {
        puts $out "  PIN [get_property NAME $pin] DIR=[get_property DIRECTION $pin] NET=[get_nets -quiet -of_objects $pin]"
    }
}

puts $out "\nPACKAGE PIN QUERIES"
foreach pin_name {AC19 AC24 V21 U20 U19 V18 Y21 Y20 W19 AA25 AA24 AB25 W20 V19 AB24 F23 H19 F25} {
    set pins [get_package_pins -quiet $pin_name]
    if {[llength $pins] == 0} {
        puts $out "$pin_name: INVALID FOR PART"
    } else {
        set pp [lindex $pins 0]
        puts $out "$pin_name: [list_property $pp]"
        foreach prop {IS_CLOCK_CAPABLE_PIN IS_GLOBAL_CLOCK_PIN IS_CCIO_PIN CLOCK_REGION BANK SITE} {
            if {[lsearch -exact [list_property $pp] $prop] >= 0} {
                puts $out "  $prop=[get_property $prop $pp]"
            }
        }
    }
}
close $out

report_drc -file [file join $report_dir drc.rpt]
report_methodology -file [file join $report_dir methodology.rpt]
report_utilization -hierarchical -file [file join $report_dir utilization_hier.rpt]
report_timing_summary -delay_type min_max -max_paths 20 -report_unconstrained -file [file join $report_dir timing_summary.rpt]
report_clock_interaction -delay_type min_max -file [file join $report_dir clock_interaction.rpt]
report_high_fanout_nets -fanout_greater_than 1000 -max_nets 100 -file [file join $report_dir high_fanout.rpt]
report_io -file [file join $report_dir io.rpt]
check_timing -verbose -file [file join $report_dir check_timing.rpt]

puts "PREFLIGHT_REPORT_DIR=$report_dir"
close_design
