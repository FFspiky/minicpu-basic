set script_dir [file dirname [file normalize [info script]]]
set checkpoint [file normalize [file join $script_dir .. project_lcd final_cpu_lcd.runs impl_1 soc_lite_lcd_top_opt.dcp]]
set report_dir [file join $script_dir reports_existing_opt]
open_checkpoint $checkpoint

set q [get_pins -quiet u_lcd_module/clk_2_reg/Q]
set c [get_pins -quiet u_lcd_module/clk_2_reg/C]
if {[llength $q] != 1 || [llength $c] != 1} {
    error "LCD divided-clock pins were not found"
}
if {[llength [get_clocks -quiet lcd_core_clk]] == 0} {
    create_generated_clock -name lcd_core_clk -source $c -divide_by 2 $q
}
check_timing -override_defaults no_clock -file [file join $report_dir lcd_clock_check.rpt]
puts "LCD_GENERATED_CLOCK=[get_clocks -of_objects $q]"
close_design
