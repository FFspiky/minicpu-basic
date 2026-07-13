# Prepare the existing final_cpu project for a clean GUI synthesis run without
# launching synthesis or implementation.
#
# From an open Vivado Tcl Console:
#   source D:/CPU_DESIGN/final_cpu/run_vivado/prepare_gui_run.tcl

set script_dir [file normalize [file dirname [info script]]]
set project_file [file join $script_dir project_lcd final_cpu_lcd.xpr]
set opened_here 0

if {[current_project -quiet] eq ""} {
    open_project $project_file
    set opened_here 1
}

# This script is specifically the gate for a fresh build. Discard old run
# products so Vivado cannot reuse a checkpoint that still references clk_pll.
if {[llength [get_runs -quiet impl_1]] != 0} {
    reset_run impl_1
}
if {[llength [get_runs -quiet synth_1]] != 0} {
    reset_run synth_1
}

source [file join $script_dir refresh_project_sources.tcl]

# board_clock_gen.v owns the PLL primitives. Remove the legacy Clock Wizard
# parent IP so stale output products and duplicate IP constraints cannot enter
# the integrated design.
foreach pll_xci [get_files -all -quiet */clk_pll.xci] {
    remove_files $pll_xci
}
foreach pll_dcp [get_files -all -quiet */clk_pll.dcp] {
    remove_files $pll_dcp
}

set required_sources {
    vga_program_menu.v uart_rx.v uart_tx.v uart_fifo.v
    nand_byte_io.v nand_raw_controller.v board_clock_gen.v
}
foreach leaf $required_sources {
    if {[llength [get_files -quiet -of_objects [get_filesets sources_1] */$leaf]] != 1} {
        error "Missing or duplicate design source: $leaf"
    }
}

set_property top soc_lite_lcd_top [get_filesets sources_1]
update_compile_order -fileset sources_1
update_compile_order -fileset sim_1

puts "GUI_RUN_PREPARED: tracked board_clock_gen active; legacy Clock Wizard removed; source set complete"

if {$opened_here} {
    close_project
}
