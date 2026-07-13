create_project -force loongson ./project -part xc7a200tfbg676-1

# Add conventional sources
add_files -scan_for_includes ../rtl

# Add IPs
add_files -quiet [glob -nocomplain ../rtl/xilinx_ip/*/*.xci]

# Add simulation files
add_files -fileset sim_1 ../testbench

# Add only the active EXP16 pipeline RTL.  Legacy teaching/reference modules
# remain on disk but are intentionally excluded from the Vivado source set.
set mycpu_files [list \
    ../../../myCPU/mycpu_top.v \
    ../../../myCPU/mycpu_pipeline.v \
    ../../../myCPU/la32_pipeline_core.v \
    ../../../myCPU/la32_pc.v \
    ../../../myCPU/la32_fetch_unit.v \
    ../../../myCPU/la32_if_id_reg.v \
    ../../../myCPU/la32_decoder.v \
    ../../../myCPU/la32_imm_gen.v \
    ../../../myCPU/regfile.v \
    ../../../myCPU/la32_id_ex_reg.v \
    ../../../myCPU/la32_exu.v \
    ../../../myCPU/la32_muldiv.v \
    ../../../myCPU/la32_branch.v \
    ../../../myCPU/la32_ex_mem_reg.v \
    ../../../myCPU/la32_lsu.v \
    ../../../myCPU/la32_mem_wb_reg.v \
    ../../../myCPU/la32_stable_counter.v \
    ../../../myCPU/la32_exception_control.v \
    ../../../myCPU/la32_csr.v \
    ../../../myCPU/la32_wb_select.v \
    ../../../myCPU/la32_pipeline_control.v \
    ../../../myCPU/la32_defs.vh \
]
add_files -scan_for_includes $mycpu_files

# Add constraints
add_files -fileset constrs_1 -quiet ./constraints/soc_lite_top.xdc

set_property -name "top" -value "tb_top" -objects  [get_filesets sim_1]
set_property -name "xsim.simulate.log_all_signals" -value "1" -objects [get_filesets sim_1]
