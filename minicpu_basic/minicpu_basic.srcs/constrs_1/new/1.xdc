##====================================================
## 实验五 MiniCPU + LCD + 单步执行 顶层约束文件
## 顶层模块：mini_cpu_display
## step_key 绑定 AC21
##====================================================

##====================================================
## 时钟与复位
##====================================================

set_property PACKAGE_PIN AC19 [get_ports clk]
set_property IOSTANDARD LVCMOS33 [get_ports clk]
create_clock -period 10.000 -name sys_clk [get_ports clk]

set_property PACKAGE_PIN Y3 [get_ports resetn]
set_property IOSTANDARD LVCMOS33 [get_ports resetn]

##====================================================
## 单步执行输入
## step_key：每次 0 -> 1 产生一个 cpu_en 脉冲
##====================================================

set_property PACKAGE_PIN AC21 [get_ports step_key]
set_property IOSTANDARD LVCMOS33 [get_ports step_key]

##====================================================
## LCD 控制接口
##====================================================

set_property PACKAGE_PIN J25 [get_ports lcd_rst]
set_property IOSTANDARD LVCMOS33 [get_ports lcd_rst]

set_property PACKAGE_PIN H18 [get_ports lcd_cs]
set_property IOSTANDARD LVCMOS33 [get_ports lcd_cs]

set_property PACKAGE_PIN K16 [get_ports lcd_rs]
set_property IOSTANDARD LVCMOS33 [get_ports lcd_rs]

set_property PACKAGE_PIN L8 [get_ports lcd_wr]
set_property IOSTANDARD LVCMOS33 [get_ports lcd_wr]

set_property PACKAGE_PIN K8 [get_ports lcd_rd]
set_property IOSTANDARD LVCMOS33 [get_ports lcd_rd]

set_property PACKAGE_PIN J15 [get_ports lcd_bl_ctr]
set_property IOSTANDARD LVCMOS33 [get_ports lcd_bl_ctr]

##====================================================
## LCD 数据总线 lcd_data_io[15:0]
##====================================================

set_property PACKAGE_PIN H9  [get_ports {lcd_data_io[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {lcd_data_io[0]}]

set_property PACKAGE_PIN K17 [get_ports {lcd_data_io[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {lcd_data_io[1]}]

set_property PACKAGE_PIN J20 [get_ports {lcd_data_io[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {lcd_data_io[2]}]

set_property PACKAGE_PIN M17 [get_ports {lcd_data_io[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {lcd_data_io[3]}]

set_property PACKAGE_PIN L17 [get_ports {lcd_data_io[4]}]
set_property IOSTANDARD LVCMOS33 [get_ports {lcd_data_io[4]}]

set_property PACKAGE_PIN L18 [get_ports {lcd_data_io[5]}]
set_property IOSTANDARD LVCMOS33 [get_ports {lcd_data_io[5]}]

set_property PACKAGE_PIN L15 [get_ports {lcd_data_io[6]}]
set_property IOSTANDARD LVCMOS33 [get_ports {lcd_data_io[6]}]

set_property PACKAGE_PIN M15 [get_ports {lcd_data_io[7]}]
set_property IOSTANDARD LVCMOS33 [get_ports {lcd_data_io[7]}]

set_property PACKAGE_PIN M16 [get_ports {lcd_data_io[8]}]
set_property IOSTANDARD LVCMOS33 [get_ports {lcd_data_io[8]}]

set_property PACKAGE_PIN L14 [get_ports {lcd_data_io[9]}]
set_property IOSTANDARD LVCMOS33 [get_ports {lcd_data_io[9]}]

set_property PACKAGE_PIN M14 [get_ports {lcd_data_io[10]}]
set_property IOSTANDARD LVCMOS33 [get_ports {lcd_data_io[10]}]

set_property PACKAGE_PIN F22 [get_ports {lcd_data_io[11]}]
set_property IOSTANDARD LVCMOS33 [get_ports {lcd_data_io[11]}]

set_property PACKAGE_PIN G22 [get_ports {lcd_data_io[12]}]
set_property IOSTANDARD LVCMOS33 [get_ports {lcd_data_io[12]}]

set_property PACKAGE_PIN G21 [get_ports {lcd_data_io[13]}]
set_property IOSTANDARD LVCMOS33 [get_ports {lcd_data_io[13]}]

set_property PACKAGE_PIN H24 [get_ports {lcd_data_io[14]}]
set_property IOSTANDARD LVCMOS33 [get_ports {lcd_data_io[14]}]

set_property PACKAGE_PIN J16 [get_ports {lcd_data_io[15]}]
set_property IOSTANDARD LVCMOS33 [get_ports {lcd_data_io[15]}]

##====================================================
## LCD 触摸接口
##====================================================

set_property PACKAGE_PIN L19 [get_ports ct_int]
set_property IOSTANDARD LVCMOS33 [get_ports ct_int]

set_property PACKAGE_PIN J24 [get_ports ct_sda]
set_property IOSTANDARD LVCMOS33 [get_ports ct_sda]

set_property PACKAGE_PIN H21 [get_ports ct_scl]
set_property IOSTANDARD LVCMOS33 [get_ports ct_scl]

set_property PACKAGE_PIN G24 [get_ports ct_rstn]
set_property IOSTANDARD LVCMOS33 [get_ports ct_rstn]