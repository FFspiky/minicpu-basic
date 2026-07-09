set ::env(CLEAN_BOARD_PROJECT) 1
set script_dir [file normalize [file dirname [info script]]]
source [file join $script_dir run_lcd_impl.tcl]
