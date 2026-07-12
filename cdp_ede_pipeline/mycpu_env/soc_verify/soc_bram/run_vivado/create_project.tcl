create_project -force loongson ./project -part xc7a200tfbg676-1

# Add conventional sources
add_files -scan_for_includes ../rtl

# Add IPs
add_files -quiet [glob -nocomplain ../rtl/xilinx_ip/*/*.xci]

# Add simulation files
add_files -fileset sim_1 ../testbench

# Add myCPU, excluding the generated reference core from active builds.
set mycpu_files [list]
foreach mycpu_file [glob -nocomplain ../../../myCPU/*.v] {
    if {[file tail $mycpu_file] ne "SimpleLACoreWrapRAM.v"} {
        lappend mycpu_files $mycpu_file
    }
}
add_files -scan_for_includes $mycpu_files

# Add constraints
add_files -fileset constrs_1 -quiet ./constraints/soc_lite_top.xdc

set_property -name "top" -value "tb_top" -objects  [get_filesets sim_1]
set_property -name "xsim.simulate.log_all_signals" -value "1" -objects [get_filesets sim_1]
