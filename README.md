# MiniCPU Basic

本仓库是基于 Vivado 2019.2 的单周期 CPU 实验工程，并已经接入指导书中的 `mycpu_env/soc_dram` 功能测试与 trace 比对框架。

当前已完成并验证的重点：

- 在 `cdp_ede_local-master/mycpu_env/myCPU` 中接入当前单周期 CPU。
- 搭建 WSL2 + Ubuntu 24.04 + LA32R 交叉编译环境。
- 生成 EXP6 功能测试程序，也就是 `func` 中的 `n1` 到 `n20`。
- 生成参考 CPU 的 `golden_trace.txt`。
- 使用 `soc_dram` testbench 对当前 CPU 的写回 trace 做自动比对。
- 当前版本已通过 EXP6 的 20 个功能测试点，仿真结果为 `----PASS!!!`。

## 目录说明

```text
.
├── cdp_ede_local-master/
│   └── mycpu_env/
│       ├── func/                         # 功能测试程序源码与生成文件
│       ├── gettrace/                     # 参考 CPU trace 生成工程
│       ├── myCPU/                        # 当前接入 soc_dram 的 CPU RTL
│       └── soc_verify/soc_dram/          # 当前使用的 trace 比对仿真环境
├── minicpu_basic/                        # 原 MiniCPU Vivado 工程
├── scripts/                              # WSL、工具链、功能测试构建脚本
└── README.md
```

## 当前 CPU 入口

主要 RTL 位于：

```text
cdp_ede_local-master/mycpu_env/myCPU/
```

其中 `mycpu_top.v` 是接入指导书环境的顶层，已经适配 `soc_lite_top` 需要的 SRAM 接口和调试写回接口：

```verilog
debug_wb_pc
debug_wb_rf_we
debug_wb_rf_wnum
debug_wb_rf_wdata
```

trace 比对框架正是通过这四个信号判断当前 CPU 和参考 CPU 是否一致。

## 环境要求

- Windows 11
- WSL2
- Ubuntu 24.04
- Vivado 2019.2
- LA32R 交叉编译工具链

本机已经验证的 Vivado 路径是：

```text
D:\Vivado\Vivado\2019.2\bin\vivado.bat
```

如果 Vivado 安装在其他位置，需要把下面命令中的路径改成自己的安装路径。

## 从 GitHub 下载后的正确复现流程

以下命令假设仓库位于：

```text
D:\CPU_DESIGN
```

如果组员 clone 到其他目录，需要把命令中的 `D:\CPU_DESIGN` 和 `/mnt/d/CPU_DESIGN` 替换成自己的仓库路径。

从 GitHub 页面下载 ZIP 时，请先把分支切到 `tree`；如果用命令行 clone，可以直接执行：

```powershell
git clone -b tree https://github.com/FFspiky/minicpu-basic.git D:\CPU_DESIGN
```

1. 先进入仓库所在目录，确认使用的是 `tree` 分支。

```powershell
cd D:\CPU_DESIGN
git branch
```

2. 首次配置 LA32R 工具链。每台电脑只需要做一次，已经装过可以跳过。

```powershell
wsl -d Ubuntu-24.04 -- sudo bash /mnt/d/CPU_DESIGN/scripts/setup_la32r_toolchain.sh
```

3. 生成 EXP6 功能测试程序。

```powershell
wsl -d Ubuntu-24.04 -- bash /mnt/d/CPU_DESIGN/scripts/build_func_exp6.sh
```

4. 生成参考 trace。

```powershell
& 'D:\Vivado\Vivado\2019.2\bin\vivado.bat' -mode batch -source 'D:\CPU_DESIGN\cdp_ede_local-master\mycpu_env\gettrace\run_gettrace_sim.tcl'
```

5. 运行当前 CPU 的 `soc_dram` trace 比对。

```powershell
& 'D:\Vivado\Vivado\2019.2\bin\vivado.bat' -mode batch -source 'D:\CPU_DESIGN\cdp_ede_local-master\mycpu_env\soc_verify\soc_dram\run_vivado\run_soc_dram_sim.tcl'
```

这一步会自动生成 Vivado 工程：

```text
D:\CPU_DESIGN\cdp_ede_local-master\mycpu_env\soc_verify\soc_dram\run_vivado\project\loongson.xpr
```

后续在 Vivado GUI 中调试时，打开这个 `loongson.xpr`。

不要打开下面这个旧工程：

```text
D:\CPU_DESIGN\minicpu_basic\minicpu_basic.xpr
```

旧工程是原 MiniCPU 工程，里面使用 `inst_rom`。本次指导书 EXP6 trace 比对环境使用的是 `mycpu_env/soc_verify/soc_dram`，里面应该看到：

```text
inst_ram : inst_ram
data_ram : data_ram
```

## 首次环境配置

进入管理员 PowerShell 或普通 PowerShell 后，先安装工具链：

```powershell
wsl -d Ubuntu-24.04 -- sudo bash /mnt/d/CPU_DESIGN/scripts/setup_la32r_toolchain.sh
```

该脚本会把 LA32R 工具链安装到 WSL 中的：

```text
/opt/loongarch32r
```

## 生成 EXP6 功能测试程序

```powershell
wsl -d Ubuntu-24.04 -- bash /mnt/d/CPU_DESIGN/scripts/build_func_exp6.sh
```

生成结果位于：

```text
cdp_ede_local-master/mycpu_env/func/obj/
```

关键文件：

```text
inst_ram.coe
inst_ram.mif
data_ram.coe
data_ram.mif
```

## 生成参考 trace

参考 trace 由 `gettrace` 工程生成：

```powershell
& 'D:\Vivado\Vivado\2019.2\bin\vivado.bat' -mode batch -source 'D:\CPU_DESIGN\cdp_ede_local-master\mycpu_env\gettrace\run_gettrace_sim.tcl'
```

生成文件：

```text
cdp_ede_local-master/mycpu_env/gettrace/golden_trace.txt
```

## 运行当前 CPU 的 trace 比对

```powershell
& 'D:\Vivado\Vivado\2019.2\bin\vivado.bat' -mode batch -source 'D:\CPU_DESIGN\cdp_ede_local-master\mycpu_env\soc_verify\soc_dram\run_vivado\run_soc_dram_sim.tcl'
```

通过时会看到：

```text
----PASS!!!
```

如果失败，testbench 会打印第一处不一致：

```text
reference: PC = ..., wb_rf_wnum = ..., wb_rf_wdata = ...
mycpu    : PC = ..., wb_rf_wnum = ..., wb_rf_wdata = ...
```

调试时优先看第一处 mismatch。

## 在 Vivado GUI 中调试

打开当前 CPU 的比对工程：

```text
D:\CPU_DESIGN\cdp_ede_local-master\mycpu_env\soc_verify\soc_dram\run_vivado\project\loongson.xpr
```

如果 `project/loongson.xpr` 不存在，先运行一次 `run_soc_dram_sim.tcl` 批处理脚本，它会自动调用 `create_project.tcl` 生成 Vivado 工程。

如果打开后看到 `inst_rom`，说明打开错了旧的 `minicpu_basic/minicpu_basic.xpr`。正确工程中应看到 `inst_ram : inst_ram`。

进入 Vivado 后：

1. 点击 `Run Simulation`。
2. 选择 `Run Behavioral Simulation`。
3. 在 Tcl Console 输入：

```tcl
run all
```

常用波形信号：

```tcl
add_wave /tb_top/debug_wb_pc
add_wave /tb_top/ref_wb_pc
add_wave /tb_top/debug_wb_rf_wnum
add_wave /tb_top/ref_wb_rf_wnum
add_wave /tb_top/debug_wb_rf_wdata_v
add_wave /tb_top/ref_wb_rf_wdata_v
add_wave /tb_top/debug_wb_err
add_wave /tb_top/soc_lite/cpu/*
```

判断方向：

- `PC` 不同：优先查 PC 更新、分支、跳转、取指。
- `PC` 相同但写回寄存器号不同：优先查译码和写使能。
- `PC`、寄存器号相同但写回数据不同：优先查 ALU、立即数、访存读数。
- 只差一个周期：优先查 `debug_wb_*` 输出时序。

## 当前支持的 EXP6 指令

当前版本面向 EXP6 的 20 条单周期 CPU 指令：

```text
lu12i.w
add.w
addi.w
sub.w
slt
sltu
and
or
xor
nor
slli.w
srli.w
srai.w
ld.w
st.w
beq
bne
bl
jirl
b
```

## 已提交的可复现实验文件

为方便复现实验，仓库中保留了：

- EXP6 生成后的 `.coe/.mif` 初始化文件。
- `golden_trace.txt`。
- WSL/工具链/构建脚本。
- Vivado 批处理仿真脚本。

Vivado 自动生成的 project/cache/sim/IP helper/log 文件已通过 `.gitignore` 排除，需要时可以由 Vivado 重新生成。
## 上板 LCD 单步验证流程

这一版新增了一个独立的上板入口，不替换原来的 trace 仿真入口：

- trace 仿真仍使用 `cdp_ede_local-master/mycpu_env/soc_verify/soc_dram/run_vivado/run_soc_dram_sim.tcl`
- 上板 LCD 调试工程使用 `cdp_ede_local-master/mycpu_env/soc_verify/soc_dram/run_vivado/create_board_project.tcl`
- 日常快速综合、实现、生成 bitstream 使用 `cdp_ede_local-master/mycpu_env/soc_verify/soc_dram/run_vivado/run_soc_dram_lcd_impl.tcl`
- 干净全量重建 bitstream 使用 `cdp_ede_local-master/mycpu_env/soc_verify/soc_dram/run_vivado/run_soc_dram_lcd_clean_impl.tcl`

上板顶层是：

```text
cdp_ede_local-master/mycpu_env/soc_verify/soc_dram/rtl/soc_lite_lcd_top.v
```

它实例化 `soc_lite_top #(.SIMULATION(1'b0), .SINGLE_STEP(1'b1))`，并接入仓库根目录下的：

```text
lcd_module_cell.dcp
```

`lcd_module_cell.dcp` 是从原始 `lcd_module.dcp` 派生的 SoC 子模块版本。脚本会从仓库根目录自动查找它，不要求仓库必须放在 `D:\CPU_DESIGN`；LCD/触摸屏真实引脚仍保留 I/O buffer，`clk/resetn/display_* / input_*` 这些逻辑接口去掉 I/O buffer，避免和 SoC 顶层时钟、内部调试信号产生冲突。

### 1. 生成功能测试程序

在生成 Vivado 上板工程前，先确保 `inst_ram.coe` 和 `data_ram.coe` 已经生成：

```powershell
cd D:\CPU_DESIGN
wsl -d Ubuntu-24.04 -- bash /mnt/d/CPU_DESIGN/scripts/build_func_exp6.sh
```

### 2. 生成上板 Vivado 工程

```powershell
& 'D:\Vivado\Vivado\2019.2\bin\vivado.bat' -mode batch -source 'D:\CPU_DESIGN\cdp_ede_local-master\mycpu_env\soc_verify\soc_dram\run_vivado\create_board_project.tcl'
```

生成后的工程路径是：

```text
D:\CPU_DESIGN\cdp_ede_local-master\mycpu_env\soc_verify\soc_dram\run_vivado\project_lcd\loongson_lcd.xpr
```

在 Vivado 里打开这个工程时，Design Sources 顶层应该是：

```text
soc_lite_lcd_top
```

其内部仍应看到：

```text
inst_ram : inst_ram
data_ram : data_ram
bridge_1x2 : bridge_1x2
u_confreg : confreg
```

如果看到 `rom` 或 `inst_rom`，说明打开了旧的 `minicpu_basic` 工程，不是当前上板工程。

### 3. 可选：检查 LCD 上板工程能否行为仿真展开

`project_lcd` 的行为仿真只用于检查上板顶层、LCD 连接和 IP 仿真模型是否能正常展开，不等价于标准 trace 比对。LCD 控制器真实实现来自 `lcd_module_cell.dcp`，行为仿真时脚本会自动使用 `run_vivado/sim/lcd_module_sim_stub.v` 作为 LCD 空壳，避免 XSim 因 DCP 网表无法展开而报 `[USF-XSim-62] elaborate failed`。

```powershell
& 'D:\Vivado\Vivado\2019.2\bin\vivado.bat' -mode batch -source 'D:\CPU_DESIGN\cdp_ede_local-master\mycpu_env\soc_verify\soc_dram\run_vivado\run_soc_dram_lcd_sim.tcl'
```

真正验证 CPU 指令功能仍然使用本文后面的 `run_soc_dram_sim.tcl` trace 比对流程。

### 4. 生成 bitstream

可以在 Vivado GUI 中点击 `Generate Bitstream`，也可以用命令快速生成。快速脚本会复用已有 `project_lcd` 和 IP 生成物，适合日常小改后重新出 bitstream：

```powershell
& 'D:\Vivado\Vivado\2019.2\bin\vivado.bat' -mode batch -source 'D:\CPU_DESIGN\cdp_ede_local-master\mycpu_env\soc_verify\soc_dram\run_vivado\run_soc_dram_lcd_impl.tcl'
```

如果怀疑 Vivado 工程缓存或 IP 生成物不干净，使用全量重建：

```powershell
& 'D:\Vivado\Vivado\2019.2\bin\vivado.bat' -mode batch -source 'D:\CPU_DESIGN\cdp_ede_local-master\mycpu_env\soc_verify\soc_dram\run_vivado\run_soc_dram_lcd_clean_impl.tcl'
```

注意：当前上板工程沿用 `soc_dram` 的 `inst_ram` distributed memory IP，首次综合仍可能较久并占用较多内存。上板脚本已关闭 IP 的 OOC checkpoint，`inst_ram` 会并入顶层 `synth_1`，不再单独运行 `inst_ram_synth_1`。

生成成功后，bitstream 通常位于：

```text
D:\CPU_DESIGN\cdp_ede_local-master\mycpu_env\soc_verify\soc_dram\run_vivado\project_lcd\loongson_lcd.runs\impl_1\soc_lite_lcd_top.bit
```

### 5. FPGA 实机操作

- 时钟仍使用 `AC19`
- 复位仍使用 `Y3`
- `switch[7]` 绑定 `AC21`，作为模式选择：`0=STEP`，`1=RUN`
- `btn_step[0]` 绑定 `Y5`，STEP 模式下按一下执行一条指令
- `btn_step[1]` 绑定 `V6`，RUN 模式下按一下开始连续运行
- RUN 模式运行到 `END_PC=1c000100` 后自动停住最终结果，直到复位

LCD 页面显示：

```text
WBPC   最后一次执行/写回 PC
INST   最近一次执行的指令
Rxx    最近一次真正写入的寄存器及其值
WRPC   最近一次真正写回发生的 PC
STEP   单步次数
NUM    confreg.num_data
MODE   当前模式，0=STEP，1=RUN
RUN    RUN 是否已经启动
DONE   RUN 是否已经停在最终结果
SW     当前拨码状态
```

### 6. 回归检查

上板单步改动不应该破坏原 trace 流程。修改 RTL 后至少重新运行：

```powershell
wsl -d Ubuntu-24.04 -- bash /mnt/d/CPU_DESIGN/scripts/build_func_exp6.sh
& 'D:\Vivado\Vivado\2019.2\bin\vivado.bat' -mode batch -source 'D:\CPU_DESIGN\cdp_ede_local-master\mycpu_env\gettrace\run_gettrace_sim.tcl'
& 'D:\Vivado\Vivado\2019.2\bin\vivado.bat' -mode batch -source 'D:\CPU_DESIGN\cdp_ede_local-master\mycpu_env\soc_verify\soc_dram\run_vivado\run_soc_dram_sim.tcl'
```

通过标准是仿真输出仍出现：

```text
----PASS!!!
```
