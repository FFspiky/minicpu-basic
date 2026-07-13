set script_dir [file normalize [file dirname [info script]]]
set project_dir [file join $script_dir project_lcd]
set synth_dcp [file join $project_dir final_cpu_lcd.runs synth_1 soc_lite_lcd_top.dcp]
set pll_dcp [file normalize [file join $script_dir .. rtl xilinx_ip clk_pll clk_pll.dcp]]
set impl_dir [file join $project_dir final_cpu_lcd.runs impl_1]
set report_dir [file join $script_dir reports]

if {![file exists $synth_dcp]} {
    error "synthesis checkpoint not found: $synth_dcp"
}

file mkdir $impl_dir
file mkdir $report_dir
open_checkpoint $synth_dcp
if {![file exists $pll_dcp]} {
    error "PLL checkpoint not found: $pll_dcp"
}
read_checkpoint -cell u_soc/pll.clk_pll $pll_dcp
read_xdc [file join $script_dir constraints soc_lite_top.xdc]
read_xdc [file join $script_dir constraints lcd_touch.xdc]

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
