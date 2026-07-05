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
