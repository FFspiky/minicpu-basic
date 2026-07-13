set part_name xc7a200tfbg676-1
create_project -in_memory -part $part_name
link_design -part $part_name -quiet

set expected_pins {
    AC19
    AC24 V21 U20 U19 V18 Y21 Y20 W19
    AA25 AA24 AB25 W20 V19 AB24
    F23 H19 F25
    T3 T2 U2 U4 R2 R1 U1 R5 P5 N1 P1 P3 U5 U6
}

set failures 0
foreach pin_name $expected_pins {
    set pin [get_package_pins -quiet $pin_name]
    if {[llength $pin] != 1} {
        puts "FAIL $pin_name does not resolve to exactly one package pin"
        incr failures
        continue
    }

    set bonded [get_property IS_BONDED $pin]
    set gpio [get_property IS_GENERAL_PURPOSE $pin]
    set bank [get_property BANK $pin]
    set function [get_property PIN_FUNC $pin]
    puts "$pin_name bonded=$bonded gpio=$gpio bank=$bank function=$function"
    if {!$bonded || (!$gpio && $pin_name ne "AC19")} {
        puts "FAIL $pin_name is not a bonded general-purpose user I/O"
        incr failures
    }
}

set clock_pin [get_package_pins AC19]
puts "AC19 clock_capable=[get_property IS_CLK_CAPABLE $clock_pin] global_clock=[get_property IS_GLOBAL_CLK $clock_pin]"
if {![get_property IS_CLK_CAPABLE $clock_pin]} {
    puts "FAIL AC19 is not clock capable for $part_name"
    incr failures
}

if {$failures != 0} {
    error "$failures package-pin validation failure(s)"
}
puts "PACKAGE_PIN_VALIDATION_PASS"
