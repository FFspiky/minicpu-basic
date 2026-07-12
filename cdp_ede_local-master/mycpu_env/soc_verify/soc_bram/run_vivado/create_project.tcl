create_project -force loongson ./project -part xc7a200tfbg676-1

# Add conventional sources
add_files -scan_for_includes ../rtl

# Add IPs
add_files -quiet [glob -nocomplain ../rtl/xilinx_ip/*/*.xci]

# Add simulation files
add_files -fileset sim_1 ../testbench

# Add myCPU explicitly. Vivado does not reliably rescan a directory already
# present in an existing project, which can leave a new hand-written core out.
set script_dir [file normalize [file dirname [info script]]]
set mycpu_dir [file normalize [file join $script_dir ../../../myCPU]]
set mycpu_files [glob -nocomplain [file join $mycpu_dir *.v]]
puts "INFO: adding [llength $mycpu_files] myCPU files from $mycpu_dir"
add_files -fileset sources_1 $mycpu_files
add_files -fileset sim_1 $mycpu_files

# Add constraints
add_files -fileset constrs_1 -quiet ./constraints/soc_lite_top.xdc

set_property -name "top" -value "tb_top" -objects  [get_filesets sim_1]
set_property -name "xsim.simulate.log_all_signals" -value "1" -objects [get_filesets sim_1]
