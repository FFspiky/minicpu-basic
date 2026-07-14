set script_dir [file normalize [file dirname [info script]]]
set run_dir [file dirname $script_dir]
cd $run_dir

source ./create_board_project.tcl
set simset [get_filesets sim_1]
set previous_top [get_property TOP $simset]
set_property TOP tb_lcd_top $simset
update_compile_order -fileset sim_1

set sim_work [file normalize [file join $run_dir project_lcd final_cpu_lcd.sim sim_1 behav xsim]]
set sim_mif_dir [file join $sim_work mem exp23]
file mkdir $sim_mif_dir
file copy -force [file normalize [file join $run_dir .. tools la32asm build racing.mif]] \
                 [file join $sim_mif_dir inst_ram.mif]

if {[catch {
    launch_simulation -simset sim_1 -mode behavioral
    run all
    if {[get_value /tb_lcd_top/test_passed] ne "1"} {
        error "LCD top regression failed; inspect [file join $sim_work simulate.log]"
    }
} error_message options]} {
    catch {close_sim -quiet}
    set_property TOP $previous_top $simset
    close_project
    return -options $options $error_message
}

close_sim
set_property TOP $previous_top $simset
close_project
puts "LCD_TOP_SIM_PASS"
