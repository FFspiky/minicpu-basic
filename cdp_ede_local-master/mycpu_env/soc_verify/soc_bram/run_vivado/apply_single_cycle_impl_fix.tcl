set script_dir [file normalize [file dirname [info script]]]
set project_file [file normalize [file join $script_dir project_lcd loongson_bram_lcd.xpr]]

if {![catch {current_project} project_name] && $project_name ne ""} {
    close_project
}
open_project $project_file

set project_dir [get_property DIRECTORY [current_project]]
set run_vivado_dir [file normalize [file join $project_dir ..]]
set opt_pre_tcl [file normalize [file join $run_vivado_dir impl_opt_design_pre.tcl]]

if {![file exists $opt_pre_tcl]} {
    error "impl_opt_design_pre.tcl not found: $opt_pre_tcl"
}

set clk_pll_ip [get_ips -quiet clk_pll]
if {$clk_pll_ip eq ""} {
    error "clk_pll IP not found in current project"
}

set clk_pll_cpu_freq [get_property CONFIG.CLKOUT1_REQUESTED_OUT_FREQ $clk_pll_ip]
set clk_pll_cpu_div  [get_property CONFIG.MMCM_CLKOUT0_DIVIDE_F $clk_pll_ip]
puts "INFO: clk_pll CPU clock request = $clk_pll_cpu_freq MHz"
puts "INFO: clk_pll CPU clock divide  = $clk_pll_cpu_div"

if {$clk_pll_cpu_freq ne "25.000" || $clk_pll_cpu_div ne "36"} {
    if {[get_property IS_LOCKED $clk_pll_ip]} {
        error "clk_pll is locked before the CPU clock can be changed to 25MHz"
    }
    set_property -dict [list \
        CONFIG.CLKOUT1_REQUESTED_OUT_FREQ {25.000} \
        CONFIG.MMCM_CLKOUT0_DIVIDE_F {36.000} \
    ] $clk_pll_ip
    puts "INFO: clk_pll new CPU clock request = [get_property CONFIG.CLKOUT1_REQUESTED_OUT_FREQ $clk_pll_ip] MHz"
}

if {[get_property IS_LOCKED $clk_pll_ip]} {
    puts "INFO: clk_pll is locked but already configured for 25MHz; rebuilding the OOC run from generated HDL."
} else {
    reset_target all $clk_pll_ip
    generate_target all $clk_pll_ip
}

set clk_pll_file [get_files -quiet [file normalize [file join $run_vivado_dir ../rtl/xilinx_ip/clk_pll/clk_pll.xci]]]
if {$clk_pll_file ne ""} {
    catch {set_property synth_checkpoint_mode Singular $clk_pll_file}
}

set clk_pll_run [get_runs -quiet clk_pll_synth_1]
if {$clk_pll_run ne ""} {
    reset_run clk_pll_synth_1
    launch_runs clk_pll_synth_1 -jobs 4
    wait_on_run clk_pll_synth_1
    puts "INFO: clk_pll_synth_1 status = [get_property STATUS [get_runs clk_pll_synth_1]]"
}

set impl_run [get_runs impl_1]
set_property STEPS.OPT_DESIGN.TCL.PRE $opt_pre_tcl $impl_run
set_property STEPS.OPT_DESIGN.ARGS.DIRECTIVE NoBramPowerOpt $impl_run
set_property STEPS.POWER_OPT_DESIGN.IS_ENABLED false $impl_run
set_property STEPS.POST_PLACE_POWER_OPT_DESIGN.IS_ENABLED false $impl_run

puts "INFO: impl_1 OPT_DESIGN directive = [get_property STEPS.OPT_DESIGN.ARGS.DIRECTIVE $impl_run]"
puts "INFO: impl_1 OPT_DESIGN pre hook = [get_property STEPS.OPT_DESIGN.TCL.PRE $impl_run]"

reset_run synth_1
reset_run impl_1
launch_runs impl_1 -to_step write_bitstream -jobs 4
