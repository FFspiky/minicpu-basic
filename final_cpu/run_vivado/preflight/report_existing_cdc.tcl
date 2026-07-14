set script_dir [file dirname [file normalize [info script]]]
set checkpoint [file normalize [file join $script_dir .. project_lcd final_cpu_lcd.runs impl_1 soc_lite_lcd_top_opt.dcp]]
set report_dir [file join $script_dir reports_existing_opt]

open_checkpoint $checkpoint
report_cdc -details -file [file join $report_dir cdc.rpt]
puts "CDC_REPORT=[file join $report_dir cdc.rpt]"
close_design
