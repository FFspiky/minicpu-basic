# Staged Vivado build entry for final_cpu.
#
# Environment interface:
#   BUILD_SCOPE=rtl         reset synthesis and implementation
#   BUILD_SCOPE=constraints preserve synthesis, reset implementation
#   BUILD_SCOPE=reuse       continue existing run products
#   BUILD_SCOPE=clean       recreate project/IP, reset both runs
#   BUILD_TARGET=synth      stop after synthesis
#   BUILD_TARGET=place      stop after place_design
#   BUILD_TARGET=bitstream  complete route and write_bitstream
#   USE_INCREMENTAL=1       use checkpoints captured after a known-good board run

set script_dir [file normalize [file dirname [info script]]]
cd $script_dir
set_param general.maxThreads 8

proc env_or_default {name default_value} {
    if {[info exists ::env($name)] && $::env($name) ne ""} {
        return [string tolower $::env($name)]
    }
    return $default_value
}

set build_scope  [env_or_default BUILD_SCOPE rtl]
set build_target [env_or_default BUILD_TARGET bitstream]
set use_incremental [env_or_default USE_INCREMENTAL 0]
set validate_only [env_or_default VALIDATE_BUILD_SCRIPT 0]

if {[lsearch -exact {rtl constraints reuse clean} $build_scope] < 0} {
    error "BUILD_SCOPE must be rtl, constraints, reuse, or clean"
}
if {[lsearch -exact {synth place bitstream} $build_target] < 0} {
    error "BUILD_TARGET must be synth, place, or bitstream"
}
if {$use_incremental ni {0 1 false true no yes}} {
    error "USE_INCREMENTAL must be 0 or 1"
}
set use_incremental [expr {$use_incremental in {1 true yes}}]

if {$build_scope eq "clean"} {
    set ::env(CLEAN_BOARD_PROJECT) 1
    set use_incremental 0
}
source ./create_board_project.tcl

set vivado_jobs 4
if {[info exists ::env(VIVADO_JOBS)] && $::env(VIVADO_JOBS) ne ""} {
    set vivado_jobs $::env(VIVADO_JOBS)
}
if {![string is integer -strict $vivado_jobs] || $vivado_jobs < 1} {
    error "VIVADO_JOBS must be a positive integer"
}
puts "BUILD_CONFIGURATION: scope=$build_scope target=$build_target jobs=$vivado_jobs maxThreads=[get_param general.maxThreads] incremental=$use_incremental"

proc synthesis_checkpoint_path {} {
    set run_dir [get_property DIRECTORY [get_runs synth_1]]
    set top_name [get_property TOP [get_filesets sources_1]]
    return [file join $run_dir ${top_name}.dcp]
}

proc synthesis_inputs_newer_than {checkpoint script_dir} {
    if {![file exists $checkpoint]} {
        return [list "missing checkpoint $checkpoint"]
    }
    set checkpoint_time [file mtime $checkpoint]
    set changed [list]
    set inputs [list]
    foreach project_input [get_files -quiet -of_objects [get_filesets sources_1]] {
        lappend inputs $project_input
    }
    lappend inputs [file normalize [file join $script_dir .. mem exp23 inst_ram.mif]]
    foreach input_file $inputs {
        set normalized [file normalize $input_file]
        if {[file exists $normalized] && [file mtime $normalized] > $checkpoint_time} {
            lappend changed $normalized
        }
    }
    return $changed
}

if {$build_scope eq "constraints"} {
    set newer_inputs [synthesis_inputs_newer_than [synthesis_checkpoint_path] $script_dir]
    if {[llength $newer_inputs] > 0} {
        error "BUILD_SCOPE=constraints cannot preserve stale synthesis. Use BUILD_SCOPE=rtl. Newer inputs: $newer_inputs"
    }
}

proc reset_if_present {run_name} {
    if {[llength [get_runs -quiet $run_name]] > 0} {
        puts "INFO: resetting $run_name"
        reset_run $run_name
    }
}

switch -- $build_scope {
    rtl - clean {
        reset_if_present impl_1
        reset_if_present synth_1
    }
    constraints {
        reset_if_present impl_1
    }
    reuse {
        puts "INFO: preserving synth_1 and impl_1 run state"
    }
}

set checkpoint_dir [file join $script_dir checkpoints]
set synth_reference [file join $checkpoint_dir stable_synth.dcp]
set impl_reference  [file join $checkpoint_dir stable_routed.dcp]
if {$use_incremental} {
    if {![file exists $synth_reference] || ![file exists $impl_reference]} {
        error "Incremental checkpoints are missing. Run capture_incremental_baseline.tcl after a known-good board test."
    }
    set_property AUTO_INCREMENTAL_CHECKPOINT false [get_runs synth_1]
    set_property WRITE_INCREMENTAL_SYNTH_CHECKPOINT true [get_runs synth_1]
    set_property INCREMENTAL_CHECKPOINT $synth_reference [get_runs synth_1]
    set_property AUTO_INCREMENTAL_CHECKPOINT false [get_runs impl_1]
    set_property INCREMENTAL_CHECKPOINT $impl_reference [get_runs impl_1]
    puts "INFO: using stable incremental checkpoints from $checkpoint_dir"
} else {
    # A structural change must not accidentally inherit an obsolete reference.
    catch {set_property AUTO_INCREMENTAL_CHECKPOINT false [get_runs synth_1]}
    catch {set_property INCREMENTAL_CHECKPOINT "" [get_runs synth_1]}
    catch {set_property AUTO_INCREMENTAL_CHECKPOINT false [get_runs impl_1]}
    catch {set_property INCREMENTAL_CHECKPOINT "" [get_runs impl_1]}
}

proc run_status {run_name} {
    return [get_property STATUS [get_runs $run_name]]
}

proc run_refresh_state {run_name} {
    set run_object [get_runs $run_name]
    if {[lsearch -exact [list_property $run_object] NEEDS_REFRESH] >= 0} {
        return [get_property NEEDS_REFRESH $run_object]
    }
    return unavailable
}

proc run_is_complete_for {run_name target_step} {
    set run_object [get_runs $run_name]
    if {[run_refresh_state $run_name] eq "1"} {
        return 0
    }
    # Vivado 2019.2 does not expose per-step STATUS properties on project
    # runs.  Successful implementation steps do leave an authoritative end
    # marker in the run directory even after CURRENT_STEP advances.
    set step_marker [file join [get_property DIRECTORY $run_object] ".${target_step}.end.rst"]
    if {[file exists $step_marker]} {
        return 1
    }
    set step_property "STEPS.[string toupper $target_step].STATUS"
    if {[lsearch -exact [list_property $run_object] $step_property] >= 0} {
        set step_status [string tolower [get_property $step_property $run_object]]
        if {[string match "complete*" $step_status]} {
            return 1
        }
    }
    # Vivado 2019.2 may leave the per-step STATUS property empty even though
    # the run-level status has already advanced to "<step> Complete!".
    # Accept that canonical run status as the fallback so a successful run is
    # not aborted before reports or the next implementation stage.
    return [expr {[string first "$target_step Complete!" [run_status $run_name]] >= 0}]
}

proc launch_to_step {run_name target_step jobs} {
    if {[run_is_complete_for $run_name $target_step]} {
        puts "INFO: $run_name already satisfies $target_step: [run_status $run_name]"
        return
    }
    puts "INFO: launching $run_name through $target_step"
    if {$target_step eq "synth_design"} {
        launch_runs $run_name -jobs $jobs
    } else {
        launch_runs $run_name -to_step $target_step -jobs $jobs
    }
    wait_on_run $run_name
    if {![run_is_complete_for $run_name $target_step]} {
        error "$run_name failed before $target_step: [run_status $run_name]"
    }
}

proc write_stage_reports {script_dir stage} {
    set report_dir [file join $script_dir reports]
    file mkdir $report_dir
    if {$stage eq "synth"} {
        open_run synth_1
        report_utilization -hierarchical -file [file join $report_dir utilization_synth.rpt]
        report_high_fanout_nets -timing -max_nets 50 \
            -file [file join $report_dir high_fanout_synth.rpt]
        report_drc -file [file join $report_dir drc_synth.rpt]
    } else {
        set impl_run_dir [get_property DIRECTORY [get_runs impl_1]]
        set top_name [get_property TOP [get_filesets sources_1]]
        set checkpoint_suffix [expr {$stage eq "place" ? "placed" : "routed"}]
        if {$stage eq "route" &&
            [get_property STEPS.POST_ROUTE_PHYS_OPT_DESIGN.IS_ENABLED [get_runs impl_1]]} {
            # Vivado writes the final, post-route-phys-opt design under this
            # suffix.  The plain routed checkpoint predates that optimization
            # and can therefore report stale negative slack even though the
            # bitstream was generated from a timing-clean design.
            set checkpoint_suffix "postroute_physopt"
        }
        set stage_checkpoint [file join $impl_run_dir ${top_name}_${checkpoint_suffix}.dcp]
        if {![file exists $stage_checkpoint]} {
            error "$stage checkpoint is missing: $stage_checkpoint"
        }
        puts "INFO: $stage timing gate uses checkpoint $stage_checkpoint"
        open_checkpoint $stage_checkpoint
        report_utilization -hierarchical -file [file join $report_dir utilization_${stage}.rpt]
        report_drc -file [file join $report_dir drc_${stage}.rpt]
        report_timing_summary -delay_type min_max -report_unconstrained \
            -check_timing_verbose -file [file join $report_dir timing_${stage}.rpt]
        if {$stage eq "route"} {
            report_timing -delay_type max -sort_by group -max_paths 20 -nworst 1 \
                -file [file join $report_dir timing_worst_20.rpt]
        }
    }
    set drc_errors [get_drc_violations -quiet -filter {SEVERITY == Error}]
    if {[llength $drc_errors] > 0} {
        error "$stage DRC contains [llength $drc_errors] error(s): $drc_errors"
    }
    if {$stage in {place route}} {
        set setup_path [get_timing_paths -quiet -delay_type max -max_paths 1]
        set hold_path  [get_timing_paths -quiet -delay_type min -max_paths 1]
        if {[llength $setup_path] == 0 || [llength $hold_path] == 0} {
            error "$stage timing analysis did not return both setup and hold paths"
        }
        set wns [get_property SLACK [lindex $setup_path 0]]
        set whs [get_property SLACK [lindex $hold_path 0]]
        puts "TIMING_GATE: stage=$stage WNS=$wns WHS=$whs"
        # Hold fixing is a routing task.  A placed-only checkpoint can have
        # negative hold slack even when implementation is healthy; keep the
        # setup gate at placement and require both setup and hold after route.
        if {$wns < 0.0 || ($stage eq "route" && $whs < 0.0)} {
            error "$stage timing gate failed: WNS=$wns WHS=$whs"
        }
    }
    puts "INFO: $stage reports written to $report_dir"
    close_design
}

if {$validate_only in {1 true yes}} {
    puts "BUILD_SCRIPT_VALID: synth_1=[run_status synth_1] synth_refresh=[run_refresh_state synth_1] impl_1=[run_status impl_1] impl_refresh=[run_refresh_state impl_1]"
    quit
}

if {$build_scope eq "constraints"} {
    if {[string first "synth_design Complete!" [run_status synth_1]] < 0} {
        error "BUILD_SCOPE=constraints requires a completed synth_1 run"
    }
    puts "INFO: preserving completed synth_1 for constraints-only build"
} else {
    launch_to_step synth_1 synth_design $vivado_jobs
}
write_stage_reports $script_dir synth
if {$build_target eq "synth"} {
    puts "BUILD_COMPLETE: synth"
    quit
}

launch_to_step impl_1 place_design $vivado_jobs
write_stage_reports $script_dir place
if {$build_target eq "place"} {
    puts "BUILD_COMPLETE: place"
    quit
}

launch_to_step impl_1 write_bitstream $vivado_jobs
write_stage_reports $script_dir route
puts "BUILD_COMPLETE: bitstream"
quit
