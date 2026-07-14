#set_property SEVERITY {Warning} [get_drc_checks RTSTAT-2]
#时钟信号连接
set_property PACKAGE_PIN AC19 [get_ports clk]
create_clock -period 10.000 -name clk -waveform {0.000 5.000} [get_ports clk]

#reset
set_property PACKAGE_PIN Y3 [get_ports resetn]

# RS-232 transceiver logic-side UART.  F25 drives the transceiver's DTR
# transmitter input; remote warm reset is encoded as BREAK on uart_rx.
set_property PACKAGE_PIN F23 [get_ports uart_rx]
set_property PACKAGE_PIN H19 [get_ports uart_tx]
set_property PACKAGE_PIN F25 [get_ports uart_dtr]

# K9F1G08U0C parallel NAND
set_property PACKAGE_PIN AC24 [get_ports {nand_io[0]}]
set_property PACKAGE_PIN W21  [get_ports {nand_io[1]}]
set_property PACKAGE_PIN U20  [get_ports {nand_io[2]}]
set_property PACKAGE_PIN U19  [get_ports {nand_io[3]}]
set_property PACKAGE_PIN V18  [get_ports {nand_io[4]}]
set_property PACKAGE_PIN Y21  [get_ports {nand_io[5]}]
set_property PACKAGE_PIN Y20  [get_ports {nand_io[6]}]
set_property PACKAGE_PIN W19  [get_ports {nand_io[7]}]
set_property PACKAGE_PIN AA25 [get_ports nand_rb_n]
set_property PACKAGE_PIN AA22 [get_ports nand_we_n]
set_property PACKAGE_PIN T19  [get_ports nand_wp_n]
set_property PACKAGE_PIN W20  [get_ports nand_ale]
set_property PACKAGE_PIN V19  [get_ports nand_cle]
set_property PACKAGE_PIN AB24 [get_ports nand_ce_n]
set_property PACKAGE_PIN AA24 [get_ports nand_re_n]

# PS/2 keyboard
set_property PACKAGE_PIN Y2  [get_ports ps2_clk]
set_property PACKAGE_PIN AD1 [get_ports ps2_data]

# VGA RGB444 and active-low sync
set_property PACKAGE_PIN T3 [get_ports {vga_r[0]}]
set_property PACKAGE_PIN T2 [get_ports {vga_r[1]}]
set_property PACKAGE_PIN U2 [get_ports {vga_r[2]}]
set_property PACKAGE_PIN U4 [get_ports {vga_r[3]}]
set_property PACKAGE_PIN R2 [get_ports {vga_g[0]}]
set_property PACKAGE_PIN R1 [get_ports {vga_g[1]}]
set_property PACKAGE_PIN U1 [get_ports {vga_g[2]}]
set_property PACKAGE_PIN R5 [get_ports {vga_g[3]}]
set_property PACKAGE_PIN P5 [get_ports {vga_b[0]}]
set_property PACKAGE_PIN N1 [get_ports {vga_b[1]}]
set_property PACKAGE_PIN P1 [get_ports {vga_b[2]}]
set_property PACKAGE_PIN P3 [get_ports {vga_b[3]}]
set_property PACKAGE_PIN U5 [get_ports vga_hsync]
set_property PACKAGE_PIN U6 [get_ports vga_vsync]


#LED
set_property PACKAGE_PIN K23 [get_ports {led[0]}]
set_property PACKAGE_PIN J21 [get_ports {led[1]}]
set_property PACKAGE_PIN H23 [get_ports {led[2]}]
set_property PACKAGE_PIN J19 [get_ports {led[3]}]
set_property PACKAGE_PIN G9  [get_ports {led[4]}]
set_property PACKAGE_PIN J26 [get_ports {led[5]}]
set_property PACKAGE_PIN J23 [get_ports {led[6]}]
set_property PACKAGE_PIN J8  [get_ports {led[7]}]
set_property PACKAGE_PIN H8  [get_ports {led[8]}]
set_property PACKAGE_PIN G8  [get_ports {led[9]}]
set_property PACKAGE_PIN F7  [get_ports {led[10]}]
set_property PACKAGE_PIN A4  [get_ports {led[11]}]
set_property PACKAGE_PIN A5  [get_ports {led[12]}]
set_property PACKAGE_PIN A3  [get_ports {led[13]}]
set_property PACKAGE_PIN D5  [get_ports {led[14]}]
set_property PACKAGE_PIN H7  [get_ports {led[15]}]

#led_rg 0/1
set_property PACKAGE_PIN G7 [get_ports {led_rg0[0]}]
set_property PACKAGE_PIN F8 [get_ports {led_rg0[1]}]
set_property PACKAGE_PIN B5 [get_ports {led_rg1[0]}]
set_property PACKAGE_PIN D6 [get_ports {led_rg1[1]}]

#NUM
set_property PACKAGE_PIN D3  [get_ports {num_csn[7]}]
set_property PACKAGE_PIN D25 [get_ports {num_csn[6]}]
set_property PACKAGE_PIN D26 [get_ports {num_csn[5]}]
set_property PACKAGE_PIN E25 [get_ports {num_csn[4]}]
set_property PACKAGE_PIN E26 [get_ports {num_csn[3]}]
set_property PACKAGE_PIN G25 [get_ports {num_csn[2]}]
set_property PACKAGE_PIN G26 [get_ports {num_csn[1]}]
set_property PACKAGE_PIN H26 [get_ports {num_csn[0]}]

set_property PACKAGE_PIN C3 [get_ports {num_a_g[0]}]
set_property PACKAGE_PIN E6 [get_ports {num_a_g[1]}]
set_property PACKAGE_PIN B2 [get_ports {num_a_g[2]}]
set_property PACKAGE_PIN B4 [get_ports {num_a_g[3]}]
set_property PACKAGE_PIN E5 [get_ports {num_a_g[4]}]
set_property PACKAGE_PIN D4 [get_ports {num_a_g[5]}]
set_property PACKAGE_PIN A2 [get_ports {num_a_g[6]}]
#set_property PACKAGE_PIN C4 :DP

# num_data is now an internal debug/MMIO bus. Its former GPIO pins are left
# available for the board peripherals, including the parallel NAND interface.

#switch
set_property PACKAGE_PIN AC21 [get_ports {switch[7]}]
set_property PACKAGE_PIN AD24 [get_ports {switch[6]}]
set_property PACKAGE_PIN AC22 [get_ports {switch[5]}]
set_property PACKAGE_PIN AC23 [get_ports {switch[4]}]
set_property PACKAGE_PIN AB6  [get_ports {switch[3]}]
set_property PACKAGE_PIN W6   [get_ports {switch[2]}]
set_property PACKAGE_PIN AA7  [get_ports {switch[1]}]
set_property PACKAGE_PIN Y6   [get_ports {switch[0]}]

#btn_key
set_property PACKAGE_PIN V8  [get_ports {btn_key_col[0]}]
set_property PACKAGE_PIN V9  [get_ports {btn_key_col[1]}]
set_property PACKAGE_PIN Y8  [get_ports {btn_key_col[2]}]
set_property PACKAGE_PIN V7  [get_ports {btn_key_col[3]}]
set_property PACKAGE_PIN U7  [get_ports {btn_key_row[0]}]
set_property PACKAGE_PIN W8  [get_ports {btn_key_row[1]}]
set_property PACKAGE_PIN Y7  [get_ports {btn_key_row[2]}]
set_property PACKAGE_PIN AA8 [get_ports {btn_key_row[3]}]

#btn_step
set_property PACKAGE_PIN Y5 [get_ports {btn_step[0]}]
set_property PACKAGE_PIN V6 [get_ports {btn_step[1]}]

set_property IOSTANDARD LVCMOS33 [get_ports clk]
set_property IOSTANDARD LVCMOS33 [get_ports resetn]
set_property IOSTANDARD LVCMOS33 [get_ports {uart_rx uart_tx uart_dtr}]
set_property IOSTANDARD LVCMOS33 [get_ports {nand_io[*] nand_rb_n nand_cle nand_ale nand_ce_n nand_re_n nand_we_n nand_wp_n}]
set_property PULLUP true [get_ports nand_rb_n]
set_property IOSTANDARD LVCMOS33 [get_ports {ps2_clk ps2_data}]
set_property PULLUP true [get_ports {ps2_clk ps2_data}]
set_property IOSTANDARD LVCMOS33 [get_ports {vga_r[*] vga_g[*] vga_b[*]}]
set_property IOSTANDARD LVCMOS33 [get_ports {vga_hsync vga_vsync}]
set_property IOSTANDARD LVCMOS33 [get_ports {led[*]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led_rg0[*]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led_rg1[*]}]
set_property IOSTANDARD LVCMOS33 [get_ports {num_a_g[*]}]
set_property IOSTANDARD LVCMOS33 [get_ports {num_csn[*]}]
set_property IOSTANDARD LVCMOS33 [get_ports {switch[*]}]
set_property IOSTANDARD LVCMOS33 [get_ports {btn_key_col[*]}]
set_property IOSTANDARD LVCMOS33 [get_ports {btn_key_row[*]}]
set_property IOSTANDARD LVCMOS33 [get_ports {btn_step[*]}]


# The prebuilt LCD cell divides its 100 MHz input by two using clk_2_reg and
# routes that clock through a BUFG.  Name the divided clock so its sequential
# logic is covered by timing analysis instead of appearing as unclocked logic.
create_generated_clock -name lcd_core_clk \
    -source [get_pins u_lcd_module/clk_2_reg/C] \
    -divide_by 2 [get_pins u_lcd_module/clk_2_reg/Q]

# CPU/peripheral transfers use synchronizers, stable-data handshakes, or are
# display-only snapshots.  They are CDC paths, not single-cycle logic paths.
# In particular, timing the former 45 MHz against 100 MHz created 1.111 ns
# requirements on more than 1400 status/display endpoints.
set_clock_groups -asynchronous \
    -group [get_clocks cpu_clk_raw] \
    -group [get_clocks {timer_clk_raw lcd_core_clk}]

# The legacy LCD block generates its font-ROM address on lcd_core_clk while
# the ROM itself is clocked by timer_clk_raw.  The address is held for a full
# 20 ns LCD cycle and consumed by the block's pipelined draw protocol; it is a
# stable-data transfer rather than a 10 ns synchronous path.
set_false_path -from [get_clocks lcd_core_clk] -to [get_clocks timer_clk_raw]

# The VGA sidebar color is sampled only on the 25 MHz pixel enable.
set vga_sidebar_pixel_regs [get_cells -hier -quiet -filter {NAME =~ *u_vga_game_top/sidebar_pixel_latched_reg*}]
set_multicycle_path -quiet -setup 4 -to $vga_sidebar_pixel_regs
set_multicycle_path -quiet -hold  3 -to $vga_sidebar_pixel_regs
