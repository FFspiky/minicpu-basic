# Refresh an already-open final_cpu Vivado project after RTL files are added.
# Run from the Tcl Console:
#   source D:/CPU_DESIGN/final_cpu/run_vivado/refresh_project_sources.tcl

set script_dir [file normalize [file dirname [info script]]]
set rtl_dir    [file normalize [file join $script_dir .. rtl]]

set rtl_files [concat \
    [glob -nocomplain [file join $rtl_dir cpu *.v]] \
    [glob -nocomplain [file join $rtl_dir lcd *.v]] \
    [glob -nocomplain [file join $rtl_dir soc *.v]] \
    [glob -nocomplain [file join $rtl_dir soc BRIDGE *.v]] \
    [glob -nocomplain [file join $rtl_dir soc CONFREG *.v]]]

if {[llength $rtl_files] == 0} {
    error "No final_cpu RTL files found below $rtl_dir"
}

set added_count 0
foreach rtl_file $rtl_files {
    set normalized [file normalize $rtl_file]
    if {[llength [get_files -quiet -of_objects [get_filesets sources_1] $normalized]] == 0} {
        add_files -fileset sources_1 -norecurse $normalized
        incr added_count
    }
}
set_property top soc_lite_lcd_top [get_filesets sources_1]
update_compile_order -fileset sources_1
update_compile_order -fileset sim_1

foreach pll_xci [get_files -all -quiet */clk_pll.xci] {
    remove_files $pll_xci
}
foreach pll_dcp [get_files -all -quiet */clk_pll.dcp] {
    remove_files $pll_dcp
}
set required_modules {
    vga_program_menu.v uart_rx.v uart_tx.v uart_fifo.v
    nand_byte_io.v nand_raw_controller.v board_clock_gen.v
}
foreach module_file $required_modules {
    set matches [get_files -quiet -of_objects [get_filesets sources_1] */$module_file]
    if {[llength $matches] == 0} {
        error "Required source was not added: $module_file"
    }
    puts "FOUND $module_file"
}

puts "final_cpu source refresh complete; added $added_count missing source(s); rerun synthesis."
