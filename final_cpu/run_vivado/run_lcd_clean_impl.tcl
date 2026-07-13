set ::env(BUILD_SCOPE) clean
set ::env(BUILD_TARGET) bitstream
set script_dir [file normalize [file dirname [info script]]]
source [file join $script_dir run_lcd_impl.tcl]
