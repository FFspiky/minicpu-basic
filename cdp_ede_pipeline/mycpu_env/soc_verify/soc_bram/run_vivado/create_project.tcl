create_project -force loongson ./project -part xc7a200tfbg676-1

# Add only the SoC sources used by the trace project. Avoid recursively
# importing generated IP products or the LCD-only top level.
add_files -scan_for_includes [list \
    ../rtl/soc_lite_top.v \
    ../rtl/BRIDGE/bridge_1x2.v \
    ../rtl/CONFREG/confreg.v \
]

# The SoC uses inferred unified RAM; only the clock wizard IP is active.
add_files -quiet ../rtl/xilinx_ip/clk_pll/clk_pll.xci

# Add simulation files
add_files -fileset sim_1 ../testbench

# Add only the active EXP16 pipeline RTL. Keep the source set explicit so
# generated projects cannot silently pick up unrelated RTL.
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

set_property -name "top" -value "soc_lite_top" -objects [get_filesets sources_1]
set_property -name "top" -value "tb_top" -objects  [get_filesets sim_1]
set_property -name "xsim.simulate.log_all_signals" -value "1" -objects [get_filesets sim_1]
update_compile_order -fileset sources_1
update_compile_order -fileset sim_1
