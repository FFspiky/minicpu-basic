set script_dir [file normalize [file dirname [info script]]]
cd $script_dir

set clean_project 0
if {[info exists ::env(CLEAN_BOARD_PROJECT)] && $::env(CLEAN_BOARD_PROJECT) ne "" && $::env(CLEAN_BOARD_PROJECT) ne "0"} {
    set clean_project 1
}

set project_dir ./project_lcd
set project_file [file join $project_dir loongson_bram_lcd.xpr]

if {$clean_project && [file exists $project_dir]} {
    file delete -force $project_dir
}

if {$clean_project} {
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
}

if {[file exists $project_file]} {
    open_project $project_file
} else {
    create_project loongson_bram_lcd $project_dir -part xc7a200tfbg676-1
}

proc filter_new_files {files} {
    set new_files {}
    foreach file $files {
        set full [file normalize $file]
        if {[llength [get_files -all -quiet $full]] == 0} {
            lappend new_files $full
        }
    }
    return $new_files
}

proc filter_new_fileset_files {files fileset_name} {
    set new_files {}
    set fileset [get_filesets $fileset_name]
    foreach file $files {
        set full [file normalize $file]
        if {[llength [get_files -quiet -of_objects $fileset $full]] == 0} {
            lappend new_files $full
        }
    }
    return $new_files
}

proc add_new_design_files {files} {
    set new_files [filter_new_fileset_files $files sources_1]
    if {[llength $new_files] > 0} {
        add_files -fileset sources_1 -scan_for_includes $new_files
    }
}

proc remove_design_file_if_present {file} {
    set full [file normalize $file]
    set existing [get_files -quiet -of_objects [get_filesets sources_1] $full]
    if {[llength $existing] > 0} {
        remove_files -fileset sources_1 $existing
    }
}

proc add_new_quiet_files {files} {
    set new_files [filter_new_files $files]
    if {[llength $new_files] > 0} {
        add_files -quiet $new_files
    }
}

proc add_new_sim_files {files} {
    set new_files [filter_new_files $files]
    if {[llength $new_files] > 0} {
        add_files -fileset sim_1 -quiet $new_files
    }
}

proc add_new_constr_files {files} {
    set new_files [filter_new_files $files]
    if {[llength $new_files] > 0} {
        add_files -fileset constrs_1 -quiet $new_files
    }
}

set rtl_files [concat \
    [glob -nocomplain ../rtl/*.v] \
    [glob -nocomplain ../rtl/BRIDGE/*.v] \
    [glob -nocomplain ../rtl/CONFREG/*.v]]
add_new_design_files $rtl_files

set ip_xci_files [list ../rtl/xilinx_ip/clk_pll/clk_pll.xci]
add_new_quiet_files $ip_xci_files
add_new_design_files [glob -nocomplain ../rtl/xilinx_ip/clk_pll/*.v]

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

set normalized_mycpu_files [list]
foreach mycpu_file $mycpu_files {
    lappend normalized_mycpu_files [file normalize $mycpu_file]
}

# An existing XPR may still contain sources added by an older wildcard-based
# script. Remove every non-whitelisted myCPU source before adding active RTL.
set mycpu_dir [file normalize ../../../myCPU]
foreach source_file [get_files -quiet -of_objects [get_filesets sources_1]] {
    set source_path [file normalize [get_property NAME $source_file]]
    if {[file dirname $source_path] eq $mycpu_dir &&
        [lsearch -exact $normalized_mycpu_files $source_path] < 0} {
        remove_files -fileset sources_1 $source_file
    }
}
add_new_design_files $mycpu_files

set board_sim_files [glob -nocomplain ./sim/*.v]
if {[llength $board_sim_files] > 0} {
    add_new_sim_files $board_sim_files
}

foreach ip_xci $ip_xci_files {
    set ip_file [get_files [file normalize $ip_xci]]
    if {$ip_file ne ""} {
        if {[catch {set_property synth_checkpoint_mode Singular $ip_file} err]} {
            puts "INFO: keep default synth_checkpoint_mode for $ip_file: $err"
        }
    }
}

set need_ip_generate $clean_project
foreach required_ip_file {
    ../rtl/xilinx_ip/clk_pll/clk_pll.v
    ../rtl/xilinx_ip/clk_pll/clk_pll_clk_wiz.v
} {
    if {![file exists $required_ip_file]} {
        set need_ip_generate 1
    }
}
if {$need_ip_generate} {
    generate_target all [get_ips]
} else {
    puts "INFO: Reusing existing generated IP products. Set CLEAN_BOARD_PROJECT=1 for a clean rebuild."
}

add_new_constr_files [list ./constraints/soc_lite_top.xdc ./constraints/lcd_touch.xdc]

set lcd_dcp [file normalize [file join $script_dir ../../../../../lcd_module_cell.dcp]]
if {![file exists $lcd_dcp]} {
    error "lcd_module_cell.dcp not found: $lcd_dcp"
}
add_new_quiet_files [list $lcd_dcp]

set_property top soc_lite_lcd_top [current_fileset]
set_property top tb_lcd_top [get_filesets sim_1]
update_compile_order -fileset sources_1
update_compile_order -fileset sim_1
