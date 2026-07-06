set script_dir [file normalize [file dirname [info script]]]
cd $script_dir

create_project -force loongson_lcd ./project_lcd -part xc7a200tfbg676-1

add_files -scan_for_includes ../rtl
add_files -quiet [glob -nocomplain ../rtl/xilinx_ip/*/*.xci]
add_files -scan_for_includes ../../../myCPU

add_files -fileset constrs_1 -quiet ./constraints/soc_lite_top.xdc
add_files -fileset constrs_1 -quiet ./constraints/lcd_touch.xdc

set lcd_dcp [file normalize [file join $script_dir ../../../../../lcd_module.dcp]]
if {![file exists $lcd_dcp]} {
    error "lcd_module.dcp not found: $lcd_dcp"
}
add_files -quiet $lcd_dcp

set_property top soc_lite_lcd_top [current_fileset]
update_compile_order -fileset sources_1
