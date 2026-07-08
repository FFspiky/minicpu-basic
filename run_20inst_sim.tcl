open_project ./minicpu_basic/minicpu_basic.xpr
update_compile_order -fileset sources_1
update_compile_order -fileset sim_1
set_property top tb_mini_cpu [get_filesets sim_1]
launch_simulation -simset sim_1 -mode behavioral
run all
quit
