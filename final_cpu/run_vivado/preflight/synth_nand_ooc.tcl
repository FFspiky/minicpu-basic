set script_dir [file normalize [file dirname [info script]]]
set root_dir [file normalize [file join $script_dir .. ..]]
set report_dir [file join $script_dir reports_nand_ooc]
file mkdir $report_dir
set_param general.maxThreads 8

create_project -in_memory nand_ooc -part xc7a200tfbg676-1
read_verilog [file join $root_dir rtl soc nand_byte_io.v]
read_verilog [file join $root_dir rtl soc nand_raw_controller.v]
synth_design -mode out_of_context -top nand_raw_controller \
    -part xc7a200tfbg676-1 -flatten_hierarchy rebuilt

report_utilization -hierarchical -file [file join $report_dir utilization.rpt]
report_high_fanout_nets -timing -max_nets 30 \
    -file [file join $report_dir high_fanout.rpt]
report_drc -file [file join $report_dir drc.rpt]
write_checkpoint -force [file join $report_dir nand_raw_controller.dcp]

set bram36 [get_cells -hier -quiet -filter {REF_NAME == RAMB36E1}]
set bram18 [get_cells -hier -quiet -filter {REF_NAME == RAMB18E1}]
set luts [get_cells -hier -quiet -filter {REF_NAME =~ LUT*}]
set ffs [get_cells -hier -quiet -filter {REF_NAME =~ FD*}]
puts "NAND_OOC_RESOURCES: LUT=[llength $luts] FF=[llength $ffs] RAMB36=[llength $bram36] RAMB18=[llength $bram18]"

if {[llength $bram36] < 1} {
    error "NAND page buffer was not inferred as RAMB36E1"
}
if {[llength $luts] >= 5000} {
    error "NAND OOC LUT gate failed: [llength $luts] >= 5000"
}
if {[llength $ffs] >= 2000} {
    error "NAND OOC FF gate failed: [llength $ffs] >= 2000"
}
if {[llength [get_drc_violations -quiet -filter {SEVERITY == Error}]] > 0} {
    error "NAND OOC DRC contains errors"
}
puts "PASS: NAND OOC BRAM and resource gates"
quit
