set script_dir [file normalize [file dirname [info script]]]
cd $script_dir

create_project -force loongson_lcd ./project_lcd -part xc7a200tfbg676-1

foreach ip_dir [glob -nocomplain ../rtl/xilinx_ip/*] {
    foreach generated_dir {doc hdl sim simulation synth} {
        file delete -force [file join $ip_dir $generated_dir]
    }
    foreach generated_pattern {
        *.dcp *.mif *.veo *.vho *.vhd *.v *.vh *.xml
        *_stub.v *_stub.vhdl *_sim_netlist.v *_sim_netlist.vhdl
        *_ooc.xdc *_board.xdc
    } {
        foreach generated_file [glob -nocomplain [file join $ip_dir $generated_pattern]] {
            file delete -force $generated_file
        }
    }
}

set rtl_files [concat \
    [glob -nocomplain ../rtl/*.v] \
    [glob -nocomplain ../rtl/BRIDGE/*.v] \
    [glob -nocomplain ../rtl/CONFREG/*.v]]
add_files -scan_for_includes $rtl_files
set ip_xci_files [glob -nocomplain ../rtl/xilinx_ip/*/*.xci]
add_files -quiet $ip_xci_files
add_files -scan_for_includes ../../../myCPU
set board_sim_files [glob -nocomplain ./sim/*.v]
if {[llength $board_sim_files] > 0} {
    add_files -fileset sim_1 -quiet $board_sim_files
}

foreach ip_xci $ip_xci_files {
    set ip_file [get_files [file normalize $ip_xci]]
    if {$ip_file ne ""} {
        if {[catch {set_property synth_checkpoint_mode None $ip_file} err]} {
            puts "INFO: keep default synth_checkpoint_mode for $ip_file: $err"
        }
    }
}
generate_target all [get_ips]

add_files -fileset constrs_1 -quiet ./constraints/soc_lite_top.xdc
add_files -fileset constrs_1 -quiet ./constraints/lcd_touch.xdc

set lcd_dcp [file normalize [file join $script_dir ../../../../../lcd_module_cell.dcp]]
if {![file exists $lcd_dcp]} {
    error "lcd_module_cell.dcp not found: $lcd_dcp"
}
add_files -quiet $lcd_dcp

set_property top soc_lite_lcd_top [current_fileset]
set_property top tb_lcd_top [get_filesets sim_1]
update_compile_order -fileset sources_1
update_compile_order -fileset sim_1
