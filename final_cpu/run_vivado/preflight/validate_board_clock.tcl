set script_dir [file dirname [file normalize [info script]]]
set clock_rtl [file normalize [file join $script_dir .. .. rtl soc board_clock_gen.v]]
set report_dir [file join $script_dir reports_clock]
file mkdir $report_dir

create_project -in_memory -part xc7a200tfbg676-1
read_verilog $clock_rtl
synth_design -top board_clock_gen -part xc7a200tfbg676-1

set_property PACKAGE_PIN AC19 [get_ports clk_in]
set_property PACKAGE_PIN Y3   [get_ports resetn]
set_property PACKAGE_PIN K23  [get_ports cpu_clk]
set_property PACKAGE_PIN J21  [get_ports timer_clk]
set_property PACKAGE_PIN H23  [get_ports locked]
set_property IOSTANDARD LVCMOS33 [get_ports *]
create_clock -name board_clk -period 10.000 [get_ports clk_in]

opt_design
place_design
report_drc -file [file join $report_dir clock_drc.rpt]
report_clock_utilization -file [file join $report_dir clock_utilization.rpt]

set errors [get_drc_violations -quiet -filter {SEVERITY == Error}]
set critical [get_drc_violations -quiet -filter {SEVERITY == {Critical Warning}}]
set reqp [get_drc_violations -quiet -filter {NAME =~ REQP-*}]
if {[llength $errors] || [llength $critical] || [llength $reqp]} {
    error "Clock preflight failed: errors=$errors critical=$critical reqp=$reqp"
}

set pll [get_cells -hier -filter {REF_NAME == PLLE2_ADV}]
set input_net [get_nets -of_objects [get_pins $pll/CLKIN1]]
puts "CLOCK_PATH_PASS pll=$pll clkin_net=$input_net"
