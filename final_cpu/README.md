# final_cpu

`final_cpu` 是当前可综合、可仿真、可上板的 LoongArch 32 位流水线 CPU SoC 工程。工程集成了模块化流水线 CPU、BRAM 存储系统、赛车游戏软件、MMIO 游戏寄存器、LCD/VGA 显示以及 PS/2 键盘输入。

本目录只保留构建和验证当前系统所需的文件，不包含参考资料、旧 EDA 工程或 Vivado 自动生成目录。

## 当前状态

- CPU：模块化五级流水线，包含前递、冒险处理、异常/CSR、TLB 和乘除法单元
- CPU 时钟：50 MHz
- 游戏逻辑：CPU 裸机软件通过 MMIO 更新车辆、障碍物、奖励、分数和难度状态
- LCD：8080 并口硬件渲染与调试显示
- VGA：赛车画面、当前分数和排行榜
- 输入：矩阵按键和 PS/2 键盘
- 最新上板实现时序：`WNS = +0.247 ns`，`TNS = 0`

## 目录结构

```text
final_cpu/
|-- rtl/
|   |-- cpu/                 模块化流水线 CPU RTL
|   |-- lcd/                 LCD 初始化、总线控制和像素渲染
|   |-- soc/                 SoC、MMIO、VGA、PS/2 和板级顶层
|   `-- xilinx_ip/           PLL、指令 RAM 和数据 RAM 的 XCI 配置
|-- sw/game/                 裸机赛车游戏源码和构建脚本
|-- mem/exp23/               指令与数据 RAM 初始化镜像
|-- lib/lcd_module_cell.dcp  LCD 调试模块依赖
|-- run_vivado/
|   |-- constraints/         FPGA 引脚与时序约束
|   |-- sim/                 RTL testbench
|   `-- *.tcl                工程创建、刷新、仿真和实现脚本
`-- README.md
```

## CPU 模块

CPU RTL 位于 `rtl/cpu/`，主要模块包括：

- `mycpu_top.v`、`mycpu_pipeline.v`：CPU 接口与流水线顶层
- `la32_fetch_unit.v`：取指控制
- `la32_decoder.v`、`la32_imm_gen.v`：译码与立即数生成
- `la32_exu.v`、`alu.v`、`cla*.v`：执行与算术逻辑
- `la32_lsu.v`：访存处理
- `la32_if_id_reg.v`、`la32_id_ex_reg.v`、`la32_ex_mem_reg.v`、`la32_mem_wb_reg.v`：流水寄存器
- `la32_forward_unit.v`、`la32_pipeline_control.v`：前递、暂停和流水控制
- `la32_commit_control.v`、`la32_exception_control.v`：提交、异常和重定向控制
- `la32_csr.v`、`la32_tlb.v`、`la32_translator.v`：CSR、TLB 和地址转换
- `la32_muldiv.v`：乘除法单元
- `regfile.v`：通用寄存器堆

## 游戏与显示

赛车游戏软件位于 `sw/game/`。CPU 通过 `confreg` 中的 MMIO 寄存器提交游戏状态，LCD 和 VGA 渲染器在显示时钟域读取一致的状态快照。

主要 MMIO 地址：

| 地址 | 寄存器 | 用途 |
| --- | --- | --- |
| `0xbfaf_9000` | `GAME_CAR` | 车辆目标车道和实际纵坐标 |
| `0xbfaf_9010` | `GAME_OBS0` | 障碍物 0 |
| `0xbfaf_9020` | `GAME_BONUS` | 奖励物 |
| `0xbfaf_9030` | `GAME_FLAGS` | 开始、暂停、结束和难度状态 |
| `0xbfaf_9040` | `GAME_SCORE` | 当前速度和分数 |
| `0xbfaf_9050` | `GAME_COMMIT` | 提交完整游戏状态 |
| `0xbfaf_9060` | `LCD_STATUS` | LCD 初始化和帧状态 |
| `0xbfaf_9070` | `GAME_OBS1` | 障碍物 1 |
| `0xbfaf_9080` | `GAME_OBS2` | 障碍物 2 |

显示相关模块：

- `rtl/lcd/lcd_game_top.v`：LCD 游戏显示顶层
- `rtl/lcd/lcd_init_engine.v`：LCD 初始化状态机
- `rtl/lcd/lcd_8080_write_master.v`：8080 写总线控制
- `rtl/lcd/racing_pixel_renderer.v`：赛车像素渲染
- `rtl/lcd/leaderboard_pixel_renderer.v`：排行榜像素渲染
- `rtl/lcd/game_state_cdc.v`：CPU 与显示时钟域状态同步
- `rtl/soc/vga_game_top.v`：VGA 游戏输出
- `rtl/soc/vga_scoreboard_renderer.v`：VGA 分数与排行榜
- `rtl/soc/ps2_game_keyboard.v`：PS/2 游戏按键输入

## 构建游戏软件

`sw/game/Makefile` 默认使用：

```text
/opt/loongarch32r/bin/loongarch32r-linux-gnusf-
```

在 WSL 中进入游戏目录并构建：

```bash
cd /mnt/d/CPU_DESIGN/final_cpu/sw/game
make install
```

`make install` 会生成 ELF、BIN、反汇编文件和 BRAM 初始化镜像，并将最新的 `inst_ram.mif`、`inst_ram.coe` 安装到 `mem/exp23/`。

只生成构建结果而不覆盖存储镜像：

```bash
make
```

清理软件构建输出：

```bash
make clean
```

## Vivado 工程

工程使用 Vivado 2019.2，目标器件为 `xc7a200tfbg676-1`，综合顶层为 `soc_lite_lcd_top`。

创建或同步 GUI 工程：

```powershell
& 'D:\Vivado\Vivado\2019.2\bin\vivado.bat' -mode batch `
  -source '.\final_cpu\run_vivado\create_board_project.tcl'
```

刷新源文件、恢复顶层并重置综合/实现运行：

```powershell
& 'D:\Vivado\Vivado\2019.2\bin\vivado.bat' -mode batch `
  -source '.\final_cpu\run_vivado\refresh_board_project.tcl'
```

随后在 Vivado GUI 中打开：

```text
final_cpu/run_vivado/project_lcd/final_cpu_lcd.xpr
```

点击 **Generate Bitstream** 即可依次运行综合、实现和 bitstream 生成。

批处理生成 bitstream：

```powershell
& 'D:\Vivado\Vivado\2019.2\bin\vivado.bat' -mode batch `
  -source '.\final_cpu\run_vivado\run_lcd_impl.tcl'
```

## 仿真

运行 LCD、VGA 和游戏外设单元仿真：

```powershell
& 'D:\Vivado\Vivado\2019.2\bin\vivado.bat' -mode batch `
  -source '.\final_cpu\run_vivado\run_lcd_unit_sim.tcl'
```

默认依次运行：

- `tb_racing_pixel_renderer`
- `tb_lcd_game_top`
- `tb_game_peripherals`

运行完整 SoC、CPU 游戏启动和 LCD 调试页冒烟仿真：

```powershell
& 'D:\Vivado\Vivado\2019.2\bin\vivado.bat' -mode batch `
  -source '.\final_cpu\run_vivado\run_lcd_sim.tcl'
```

完整仿真顶层为 `tb_lcd_top`。

## 版本库约定

- 保留源码、约束、Tcl 脚本、必要 IP 配置、存储镜像和 LCD DCP。
- 不提交 `project_lcd/`、Vivado 日志、仿真快照、综合/实现运行目录和 bitstream。
- 不在 `main` 的 `final_cpu` 中保存参考 PDF、压缩包、旧 EDA 工程或历史实验副本。
