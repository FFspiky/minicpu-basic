# MiniCPU Basic

本仓库是基于 Vivado 2019.2 的 LoongArch CPU 设计实验工程。当前版本在原有单周期 CPU 的基础上新增了五级流水线 CPU，并接入 `mycpu_env/soc_verify/soc_dram` trace 对拍验证环境。

## 当前版本状态

- 默认 CPU：五级流水线 CPU。
- 保留实现：原单周期 CPU 已保留为 `mycpu_single_cycle`。
- 统一顶层：`mycpu_top` 作为 wrapper，通过参数选择单周期或流水线。
- 默认 trace 环境：`soc_dram` 中默认实例化流水线 CPU。
- 当前指令范围：n1-n20，即 `lu12i.w/add.w/addi.w/sub.w/slt/sltu/and/or/xor/nor/slli.w/srli.w/srai.w/ld.w/st.w/beq/bne/bl/jirl/b`。
- 已验证：单周期 EXP6 PASS；流水线 EXP6、EXP8、EXP9 PASS。

## 关键目录

```text
.
├── cdp_ede_local-master/
│   └── mycpu_env/
│       ├── func/                         # 功能测试程序源码与生成文件
│       ├── gettrace/                     # golden_trace 生成工程
│       ├── myCPU/                        # CPU RTL
│       │   ├── mycpu_top.v               # 单周期实现 + wrapper 顶层
│       │   └── mycpu_pipeline.v          # 五级流水线实现
│       └── soc_verify/soc_dram/          # 当前 trace 对拍仿真环境
├── minicpu_basic/                        # 原 MiniCPU Vivado 工程
├── scripts/                              # WSL、工具链、功能测试构建脚本
└── README.md
```

## CPU 选择方式

`mycpu_top` 默认参数如下：

```verilog
parameter USE_PIPELINE = 1'b1
```

在 `soc_dram` 验证环境中，`soc_lite_top` 也提供参数：

```verilog
parameter CPU_USE_PIPELINE = 1'b1
```

需要切回单周期验证时，把 `CPU_USE_PIPELINE` 设为 `1'b0`，接口和 trace testbench 不需要改。

## 流水线实现要点

新增的 `mycpu_pipeline.v` 实现 IF、ID、EX、MEM、WB 五级流水线，并包含：

- IF/ID、ID/EX、EX/MEM、MEM/WB 四级流水寄存器和 valid 位。
- EX/MEM、MEM/WB 前递，且 EX/MEM 优先。
- load-use 冒险暂停：保持 PC 和 IF/ID，向 ID/EX 注入气泡。
- 分支/跳转在 EX 级判定，taken 时冲刷 IF/ID 和 ID/EX。
- store 数据前递。
- WB 同周期读写旁路。
- `debug_wb_pc` 使用 MEM/WB 携带的原始指令 PC。
- `lu12i.w` 保留立即数写回路径，`bl/jirl` 保留 `PC+4` 写回路径。

## 环境要求

- Windows 11
- WSL2 + Ubuntu 24.04
- Vivado 2019.2
- LA32R 交叉编译工具链

本机已验证 Vivado 路径：

```text
D:\Vivado\Vivado\2019.2\bin\vivado.bat
```

如果 Vivado 安装在其他位置，需要替换下面命令里的路径。

## 复现验证流程

以下命令假设仓库位于：

```text
D:\CPU_DESIGN
```

如果 clone 到其他目录，请同步替换 Windows 路径和 WSL 路径。

### 1. 克隆仓库

```powershell
git clone -b tree https://github.com/FFspiky/minicpu-basic.git D:\CPU_DESIGN
cd D:\CPU_DESIGN
```

### 2. 安装 LA32R 工具链

每台机器只需要执行一次：

```powershell
wsl -d Ubuntu-24.04 -- sudo bash /mnt/d/CPU_DESIGN/scripts/setup_la32r_toolchain.sh
```

### 3. 生成功能测试程序

默认生成 EXP6：

```powershell
wsl -d Ubuntu-24.04 -- bash /mnt/d/CPU_DESIGN/scripts/build_func_exp6.sh
```

生成 EXP8 或 EXP9：

```powershell
wsl -d Ubuntu-24.04 -- bash /mnt/d/CPU_DESIGN/scripts/build_func_exp6.sh 8
wsl -d Ubuntu-24.04 -- bash /mnt/d/CPU_DESIGN/scripts/build_func_exp6.sh 9
```

生成结果位于：

```text
cdp_ede_local-master/mycpu_env/func/obj/
```

### 4. 生成 golden trace

```powershell
& 'D:\Vivado\Vivado\2019.2\bin\vivado.bat' -mode batch -source 'D:\CPU_DESIGN\cdp_ede_local-master\mycpu_env\gettrace\run_gettrace_sim.tcl'
```

生成文件：

```text
cdp_ede_local-master/mycpu_env/gettrace/golden_trace.txt
```

### 5. 运行当前 CPU trace 对拍

```powershell
& 'D:\Vivado\Vivado\2019.2\bin\vivado.bat' -mode batch -source 'D:\CPU_DESIGN\cdp_ede_local-master\mycpu_env\soc_verify\soc_dram\run_vivado\run_soc_dram_sim.tcl'
```

通过时会看到：

```text
----PASS!!!
```

## 已验证结果

本版本已经完成以下验证：

```text
Verilog syntax check                 PASS
single-cycle CPU + EXP6 trace         PASS
pipeline CPU + EXP6 trace             PASS
pipeline CPU + EXP8 trace             PASS
pipeline CPU + EXP9 trace             PASS
```

EXP8/EXP9 是 n1-n20 无 NOP 测试，重点覆盖数据相关、load-use 暂停、分支/跳转冲刷、`bl/jirl` 写回和 `lu12i.w` 写回。

## Vivado GUI 调试入口

trace 对拍工程由脚本自动生成：

```text
D:\CPU_DESIGN\cdp_ede_local-master\mycpu_env\soc_verify\soc_dram\run_vivado\project\loongson.xpr
```

如果 `project/loongson.xpr` 不存在，先运行一次 `run_soc_dram_sim.tcl`。

不要打开旧工程：

```text
D:\CPU_DESIGN\minicpu_basic\minicpu_basic.xpr
```

当前 trace 对拍环境应看到 `inst_ram : inst_ram` 和 `data_ram : data_ram`。

## 上板 LCD 单步调试

上板入口仍为：

```text
cdp_ede_local-master/mycpu_env/soc_verify/soc_dram/rtl/soc_lite_lcd_top.v
```

该顶层透传 `CPU_USE_PIPELINE` 参数，默认同样使用流水线 CPU。需要使用单周期上板调试时，也可以把该参数切为 `1'b0`。

常用脚本：

```powershell
& 'D:\Vivado\Vivado\2019.2\bin\vivado.bat' -mode batch -source 'D:\CPU_DESIGN\cdp_ede_local-master\mycpu_env\soc_verify\soc_dram\run_vivado\create_board_project.tcl'
& 'D:\Vivado\Vivado\2019.2\bin\vivado.bat' -mode batch -source 'D:\CPU_DESIGN\cdp_ede_local-master\mycpu_env\soc_verify\soc_dram\run_vivado\run_soc_dram_lcd_impl.tcl'
```

## 注意事项

- `soc_dram` 仿真 RAM 已扩到 18 位字地址，避免 EXP8/9 长程序被 `[17:2]` 截断取指。
- 数据存储器仍沿用当前 1 位写使能接口，未扩展字节写使能。
- 当前流水线只面向 n1-n20 指令范围，未实现 EXP10 之后新增指令和异常/TLB/Cache。
