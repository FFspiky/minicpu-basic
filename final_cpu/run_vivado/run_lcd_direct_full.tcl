set script_dir [file normalize [file dirname [info script]]]
cd $script_dir

source ./create_board_project.tcl

set part xc7a200tfbg676-1
set impl_dir [file join $script_dir project_lcd final_cpu_lcd.runs impl_1]
set report_dir [file join $script_dir reports]

synth_design -top soc_lite_lcd_top -part $part

file mkdir $impl_dir
file mkdir $report_dir
opt_design
place_design -directive ExtraNetDelay_high
phys_opt_design -directive Explore
route_design -directive Explore
phys_opt_design -directive Explore

report_timing_summary -delay_type max -report_unconstrained -check_timing_verbose \
    -file [file join $report_dir timing_summary.rpt]
report_timing -delay_type max -sort_by group -max_paths 20 -nworst 1 \
    -file [file join $report_dir timing_worst_20.rpt]
write_checkpoint -force [file join $impl_dir soc_lite_lcd_top_routed.dcp]
write_bitstream -force [file join $impl_dir soc_lite_lcd_top.bit]

quit
