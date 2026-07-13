set script_dir [file dirname [file normalize [info script]]]
set project_file [file normalize [file join $script_dir .. project_lcd final_cpu_lcd.xpr]]
set report_dir [file join $script_dir reports_project]
file mkdir $report_dir
open_project $project_file
report_ip_status -file [file join $report_dir ip_status.rpt]
set pll [get_ips -quiet clk_pll]
set pll_xci [get_files -all -quiet */clk_pll.xci]
set pll_dcp [get_files -all -quiet */clk_pll.dcp]
if {[llength $pll] != 0 || [llength $pll_xci] != 0 || [llength $pll_dcp] != 0} {
    error "Legacy clk_pll artifacts are still active: IP=$pll XCI=$pll_xci DCP=$pll_dcp"
}
puts "PLL_IP_ABSENT=PASS (board_clock_gen.v owns the PLL primitives)"
foreach ip [get_ips -quiet] {
    puts "IP=[get_property NAME $ip] LOCKED=[get_property IS_LOCKED $ip]"
}
close_project
