set script_dir [file normalize [file dirname [info script]]]
cd $script_dir

source ./create_board_project.tcl

set test_tops {tb_racing_pixel_renderer tb_lcd_game_top tb_game_peripherals}
if {[info exists ::env(LCD_UNIT_TOP)] && $::env(LCD_UNIT_TOP) ne ""} {
    set test_tops [list $::env(LCD_UNIT_TOP)]
}

foreach test_top $test_tops {
    set_property top $test_top [get_filesets sim_1]
    update_compile_order -fileset sim_1
    launch_simulation -simset sim_1 -mode behavioral
    run all
    close_sim
}

quit
