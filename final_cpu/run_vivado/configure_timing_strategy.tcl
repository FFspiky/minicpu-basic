# Timing-oriented implementation settings for the final_cpu board build.
#
# The current critical paths are shallow lcd_module font-ROM address paths
# whose delay is dominated by routing.  Keep synthesis and RTL unchanged and
# ask implementation to spend more effort on placement and routing instead.

set impl_run [get_runs -quiet impl_1]
if {[llength $impl_run] != 1} {
    error "Expected exactly one impl_1 run"
}

# ExtraNetDelay_high biases placement toward reducing interconnect delay.  It
# is a better match than logic-remapping options for the routed LCD DCP path.
set_property STEPS.PLACE_DESIGN.ARGS.DIRECTIVE ExtraNetDelay_high $impl_run

# Explore placement-created timing opportunities before routing.  The LCD DCP
# is functionally fixed; this step may replicate/move surrounding legal cells
# without changing the logical netlist behavior.
set_property STEPS.PHYS_OPT_DESIGN.IS_ENABLED true $impl_run
set_property STEPS.PHYS_OPT_DESIGN.ARGS.DIRECTIVE Explore $impl_run

# Explore performs timing-driven alternative routing instead of accepting the
# first legal route, important for the 8-10 ns route-dominated LCD nets.
set_property STEPS.ROUTE_DESIGN.ARGS.DIRECTIVE Explore $impl_run

# Give Vivado a final chance to repair the few remaining negative-slack paths
# after their real routed delays are known.
set_property STEPS.POST_ROUTE_PHYS_OPT_DESIGN.IS_ENABLED true $impl_run
set_property STEPS.POST_ROUTE_PHYS_OPT_DESIGN.ARGS.DIRECTIVE Explore $impl_run

puts "TIMING_STRATEGY_CONFIGURED: place=ExtraNetDelay_high phys_opt=Explore route=Explore post_route_phys_opt=Explore"
