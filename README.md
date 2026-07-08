# MiniCPU Basic

这是一个基于 Vivado 2019.2 的单周期 MiniCPU 工程，目标器件为 `xc7a200tfbg676-1`。工程顶层为 `mini_cpu_display`，CPU 核心顶层为 `mini_cpu`，支持单步执行并通过 LCD 显示调试信息。

## 工程内容

```text
.
├── init.coe                         # 指令 ROM 初始化文件
├── lcd_module.dcp                   # LCD 模块预综合网表
├── minicpu.drawio                   # CPU 数据通路图
└── minicpu_basic/
    ├── minicpu_basic.xpr            # Vivado 工程文件
    └── minicpu_basic.srcs/
        ├── constrs_1/new/1.xdc      # 板级约束
        ├── sim_1/new/tb_mini_cpu.v  # 仿真 testbench
        └── sources_1/
            ├── new/                 # 手写 CPU RTL
            └── ip/                  # Vivado IP 配置
```

Vivado 的缓存、仿真输出、综合实现输出和日志文件没有纳入仓库，可由 Vivado 重新生成。

## 整体架构

该 CPU 是一个单周期、非流水线、哈佛结构的 MiniCPU。指令存储器和数据存储器分离，每次 `cpu_en` 有效时完成一条指令的执行，并在时钟上升沿更新 PC、寄存器堆和数据 RAM 写入状态。

核心数据通路如下：

```text
PC -> inst_rom -> inst_decode -> cpu_control
                         |           |
                         v           v
                    regfile -----> ALU -----> data_ram
                       |            |             |
                       |            v             v
                       +------ branch_unit     writeback
```

数据通路图文件为 `minicpu.drawio`，可以用 draw.io 或 diagrams.net 打开。

## 主要部件

### `mini_cpu`

CPU 核心顶层，连接取指、译码、控制、寄存器堆、ALU、数据 RAM、写回、分支和调试模块。

### `ifetch_unit`

取指单元。PC 复位地址为 `0x1c000000`，顺序执行时 `seq_pc = pc + 4`。访问指令 ROM 时使用：

```verilog
inst_addr = (pc - 32'h1c000000) >> 2;
```

### `inst_decode`

指令译码单元，从 32 位指令中拆分：

- `rd = inst[4:0]`
- `rj = inst[9:5]`
- `rk = inst[14:10]`
- `imm12 = inst[21:10]`
- `offs16 = inst[25:10]`

当前识别 `add.w`、`addi.w`、`ld.w`、`st.w`、`bne`、`sub.w`、`and`、`or`。

### `cpu_control`

控制单元，根据译码结果生成：

- `sel_rf_ra2`：寄存器堆第二读地址选择
- `sel_alu_src2`：ALU 第二操作数选择
- `data_ram_we`：数据 RAM 写使能
- `rf_we`：寄存器堆写使能
- `sel_rf_res`：写回数据来源选择
- `alu_op`：ALU 运算选择

### `regfile`

32 个 32 位通用寄存器，2 个异步读端口、1 个同步写端口。`r0` 恒为 0，写入 `r0` 会被忽略。

### `alu`

32 位 ALU，内部使用 `cla32` 先行进位加法器完成加减法。ALU 运算能力包括：

- 加法
- 减法
- 有符号小于比较 `slt`
- 无符号小于比较 `sltu`
- 按位与
- 按位或
- 逻辑左移
- 逻辑右移

当前指令控制实际使用了 add、sub、and、or。`slt`、`sltu`、`sll`、`srl` 的 ALU 逻辑已存在，但还没有接入完整指令译码和控制。

### `cla4`、`cla16`、`cla32`

三级先行进位加法器结构。`cla4` 构成 4 位加法块，`cla16` 由 4 个 `cla4` 组成，`cla32` 由两个 `cla16` 组成。

### `imm_extend`

立即数扩展单元：

- `imm12` 符号扩展为 32 位
- `offs16` 左移 2 位后符号扩展为分支偏移

### `data_addr_gen`

数据 RAM 地址生成单元，取 ALU 结果的 `byte_addr[17:2]` 作为字地址。因此当前访存按 word 对齐处理，不支持字节/半字访存和非对齐异常。

### `branch_unit`

分支判断单元。当前只支持 `bne`：

```text
if rj != rd:
    next_pc = pc + sign_extend(offs16 << 2)
else:
    next_pc = pc + 4
```

### `store_debug`

store 调试模块。每次执行 `st.w` 时记录：

- 是否执行过 store：`debug_done`
- store 次数：`debug_store_count`
- 最近一次 store 地址：`debug_last_store_addr`
- 最近一次 store 数据：`debug_last_store_data`

### `mini_cpu_display`

上板顶层模块，负责：

- 对 `step_key` 做同步、消抖和上升沿检测
- 产生单周期 `cpu_en`，实现单步执行
- 维护单步计数器
- 实例化 `mini_cpu`
- 实例化外部 LCD 模块 `lcd_module`
- 在 LCD 上显示 PC、当前指令、步数和 store 调试信息

## 存储器

### 指令 ROM

`inst_rom` 是 Vivado `dist_mem_gen` 生成的 ROM：

- 深度：65536
- 宽度：32 bit
- 读方式：异步读
- 初始化：`init.coe` / `inst_rom.mif`

### 数据 RAM

`data_ram` 是 Vivado `dist_mem_gen` 生成的单端口 RAM：

- 深度：65536
- 宽度：32 bit
- 写方式：同步写
- 读方式：异步读

## 指令集

| 指令 | 功能 |
| --- | --- |
| `add.w rd, rj, rk` | `rd = rj + rk` |
| `addi.w rd, rj, imm12` | `rd = rj + sign_extend(imm12)` |
| `sub.w rd, rj, rk` | `rd = rj - rk` |
| `and rd, rj, rk` | `rd = rj & rk` |
| `or rd, rj, rk` | `rd = rj | rk` |
| `ld.w rd, rj, imm12` | `rd = data_ram[(rj + sign_extend(imm12))[17:2]]` |
| `st.w rd, rj, imm12` | `data_ram[(rj + sign_extend(imm12))[17:2]] = rd` |
| `bne rj, rd, offs16` | 若 `rj != rd`，跳转到 `pc + sign_extend(offs16 << 2)` |

## ROM 示例程序

`init.coe` 中的程序会计算并存储 `10 - 3`、`10 & 3`、`10 | 3` 的结果，然后进入自循环：

```asm
addi.w r1, r0, 10
addi.w r2, r0, 3
sub.w  r4, r1, r2
and    r5, r1, r2
or     r6, r1, r2
st.w   r4, r0, 0
st.w   r5, r0, 4
st.w   r6, r0, 8
addi.w r1, r0, 1
bne    r1, r0, -1
```

## 仿真

仿真顶层为 `tb_mini_cpu`。testbench 会复位 CPU，然后通过 `cpu_en` 单步执行 80 条指令，并打印：

- 当前 PC
- 当前指令
- 是否执行过 store
- store 次数
- 最近一次 store 地址
- 最近一次 store 数据

## 打开工程

1. 使用 Vivado 2019.2 打开 `minicpu_basic/minicpu_basic.xpr`。
2. 确认 `lcd_module.dcp` 位于仓库根目录；工程中的引用路径为 `$PPRDIR/../../lcd_module.dcp`。
3. 如 IP 状态提示需要刷新，重新生成 `inst_rom` 和 `data_ram` 的输出产物。
4. 综合/实现顶层为 `mini_cpu_display`，仿真顶层为 `tb_mini_cpu`。
