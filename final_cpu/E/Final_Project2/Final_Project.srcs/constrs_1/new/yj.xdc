# ============================================================================
# 1. 时钟与复位
# ============================================================================
set_property PACKAGE_PIN AC19 [get_ports clk]
set_property IOSTANDARD LVCMOS33 [get_ports clk]

set_property PACKAGE_PIN Y3 [get_ports rst_n]
set_property IOSTANDARD LVCMOS33 [get_ports rst_n]

# ============================================================================
# 2. LCD 屏幕接口 (关键修正版)
# ============================================================================
# 控制线
set_property PACKAGE_PIN J25 [get_ports lcd_rst]
set_property PACKAGE_PIN H18 [get_ports lcd_cs]
set_property PACKAGE_PIN K16 [get_ports lcd_rs]
set_property PACKAGE_PIN L8  [get_ports lcd_wr]
set_property PACKAGE_PIN K8  [get_ports lcd_rd]
set_property PACKAGE_PIN J15 [get_ports lcd_bl_ctr]
set_property IOSTANDARD LVCMOS33 [get_ports lcd_*]

# ============================================================================
# LCD 数据线映射 (完美适配 16 根物理连线)
# ============================================================================

# 低 8 位 (直接对应 DB1 - DB8)
set_property PACKAGE_PIN H9  [get_ports {lcd_db[0]}]   ; # 对应板上 LCD1_DB1
set_property PACKAGE_PIN K17 [get_ports {lcd_db[1]}]   ; # 对应板上 LCD1_DB2
set_property PACKAGE_PIN J20 [get_ports {lcd_db[2]}]   ; # 对应板上 LCD1_DB3
set_property PACKAGE_PIN M17 [get_ports {lcd_db[3]}]   ; # 对应板上 LCD1_DB4
set_property PACKAGE_PIN L17 [get_ports {lcd_db[4]}]   ; # 对应板上 LCD1_DB5
set_property PACKAGE_PIN L18 [get_ports {lcd_db[5]}]   ; # 对应板上 LCD1_DB6
set_property PACKAGE_PIN L15 [get_ports {lcd_db[6]}]   ; # 对应板上 LCD1_DB7
set_property PACKAGE_PIN M15 [get_ports {lcd_db[7]}]   ; # 对应板上 LCD1_DB8

# 高 8 位 (跳过缺失的 DB9，直接从 DB10 开始接)
# ? 之前报错的 lcd_db[8] 现在连到了 M16 (DB10)
set_property PACKAGE_PIN M16 [get_ports {lcd_db[8]}]   ; # 对应板上 LCD1_DB10
set_property PACKAGE_PIN L14 [get_ports {lcd_db[9]}]   ; # 对应板上 LCD1_DB11
set_property PACKAGE_PIN M14 [get_ports {lcd_db[10]}]  ; # 对应板上 LCD1_DB12
set_property PACKAGE_PIN F22 [get_ports {lcd_db[11]}]  ; # 对应板上 LCD1_DB13
set_property PACKAGE_PIN G22 [get_ports {lcd_db[12]}]  ; # 对应板上 LCD1_DB14
set_property PACKAGE_PIN G21 [get_ports {lcd_db[13]}]  ; # 对应板上 LCD1_DB15
set_property PACKAGE_PIN H24 [get_ports {lcd_db[14]}]  ; # 对应板上 LCD1_DB16
set_property PACKAGE_PIN J16 [get_ports {lcd_db[15]}]  ; # 对应板上 LCD1_DB17

# 统一电压标准
set_property IOSTANDARD LVCMOS33 [get_ports {lcd_db[*]}]

# ============================================================================
# 3. 矩阵键盘与 LED (按键修正版)
# ============================================================================
# 键盘列 (V8, V9, Y8, V7)
set_property PACKAGE_PIN V8 [get_ports {key_col[0]}]
set_property PACKAGE_PIN V9 [get_ports {key_col[1]}]
set_property PACKAGE_PIN Y8 [get_ports {key_col[2]}]
set_property PACKAGE_PIN V7 [get_ports {key_col[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {key_col[*]}]

# 键盘行 (U7, W8, Y7, AA8)
set_property PACKAGE_PIN U7  [get_ports {key_row[0]}]
set_property PACKAGE_PIN W8  [get_ports {key_row[1]}]
set_property PACKAGE_PIN Y7  [get_ports {key_row[2]}]
set_property PACKAGE_PIN AA8 [get_ports {key_row[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {key_row[*]}]

# LED (补全所有16位, 修正 K23)
set_property PACKAGE_PIN H7  [get_ports {leds[0]}]
set_property PACKAGE_PIN D5  [get_ports {leds[1]}]
set_property PACKAGE_PIN A3  [get_ports {leds[2]}]
set_property PACKAGE_PIN A5  [get_ports {leds[3]}]
set_property PACKAGE_PIN A4  [get_ports {leds[4]}]
set_property PACKAGE_PIN F7  [get_ports {leds[5]}]
set_property PACKAGE_PIN G8  [get_ports {leds[6]}]
set_property PACKAGE_PIN H8  [get_ports {leds[7]}]
set_property PACKAGE_PIN J8  [get_ports {leds[8]}]
set_property PACKAGE_PIN J23 [get_ports {leds[9]}]
set_property PACKAGE_PIN J26 [get_ports {leds[10]}]
set_property PACKAGE_PIN G9  [get_ports {leds[11]}]
set_property PACKAGE_PIN J19 [get_ports {leds[12]}]
set_property PACKAGE_PIN H23 [get_ports {leds[13]}]
set_property PACKAGE_PIN J21 [get_ports {leds[14]}]
set_property PACKAGE_PIN K23 [get_ports {leds[15]}]
set_property IOSTANDARD LVCMOS33 [get_ports {leds[*]}]

# ============================================================================
# 4. 八段数码管 (共阴极，使用前 4 位)
#    对应表：八段数码管工作表
#    FPGA_NUM_CSN0..3   -> seg_an[0..3]
#    FPGA_NUM0_A..7_DP  -> seg_cat[0..7] (a,b,c,d,e,f,g,dp)
# ============================================================================
# 位选（片选），低电平点亮；8 位都用
set_property PACKAGE_PIN D3  [get_ports {seg_an[0]}]  ; # FPGA_NUM_CSN0 左起第1个
set_property PACKAGE_PIN D25 [get_ports {seg_an[1]}]  ; # FPGA_NUM_CSN1
set_property PACKAGE_PIN D26 [get_ports {seg_an[2]}]  ; # FPGA_NUM_CSN2
set_property PACKAGE_PIN E25 [get_ports {seg_an[3]}]  ; # FPGA_NUM_CSN3
set_property PACKAGE_PIN E26 [get_ports {seg_an[4]}]  ; # FPGA_NUM_CSN4
set_property PACKAGE_PIN G25 [get_ports {seg_an[5]}]  ; # FPGA_NUM_CSN5
set_property PACKAGE_PIN G26 [get_ports {seg_an[6]}]  ; # FPGA_NUM_CSN6
set_property PACKAGE_PIN H26 [get_ports {seg_an[7]}]  ; # FPGA_NUM_CSN7 左起第8个
set_property IOSTANDARD LVCMOS33 [get_ports {seg_an[*]}]


# 段选（a,b,c,d,e,f,g,dp），低电平点亮
# seg_cat[7:0] = {dp,g,f,e,d,c,b,a}
set_property PACKAGE_PIN A2 [get_ports {seg_cat[0]}]  ; # FPGA_NUM0_A  -> a 段
set_property PACKAGE_PIN D4 [get_ports {seg_cat[1]}]  ; # FPGA_NUM1_B  -> b 段
set_property PACKAGE_PIN E5 [get_ports {seg_cat[2]}]  ; # FPGA_NUM2_C  -> c 段
set_property PACKAGE_PIN B4 [get_ports {seg_cat[3]}]  ; # FPGA_NUM3_D  -> d 段
set_property PACKAGE_PIN B2 [get_ports {seg_cat[4]}]  ; # FPGA_NUM4_E  -> e 段
set_property PACKAGE_PIN E6 [get_ports {seg_cat[5]}]  ; # FPGA_NUM5_F  -> f 段
set_property PACKAGE_PIN C3 [get_ports {seg_cat[6]}]  ; # FPGA_NUM6_G  -> g 段
set_property PACKAGE_PIN C4 [get_ports {seg_cat[7]}]  ; # FPGA_NUM7_DP -> 小数点 dp
set_property IOSTANDARD LVCMOS33 [get_ports {seg_cat[*]}]
