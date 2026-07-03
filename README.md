# MiniCPU Basic

这是一个基于 Vivado 2019.2 的单周期 MiniCPU 工程。当前版本已按仓库中的单周期数据通路图和修正后的控制信号取值表完成 RTL 重构，并通过 Vivado 行为仿真验证。

## 工程内容

```text
.
├── init.coe                         # 默认 ROM 示例程序
├── init_20inst_verify.coe           # 20 条指令专用验证程序
├── 控制信号取值表 .xlsx             # 已修正的控制信号表
├── 单周期数据通路图.drawio          # 单周期 CPU 数据通路图
├── lcd_module.dcp                   # LCD 预综合模块
├── run_20inst_sim.tcl               # Vivado 行为仿真脚本
└── minicpu_basic/
    ├── minicpu_basic.xpr            # Vivado 工程文件
    └── minicpu_basic.srcs/
        ├── constrs_1/new/1.xdc
        ├── sim_1/new/tb_mini_cpu.v
        └── sources_1/
            ├── new/                 # 手写 CPU RTL
            └── ip/                  # Vivado ROM/RAM IP 配置
```

Vivado 生成的缓存、仿真输出、综合实现输出和日志文件不纳入仓库，可由 Vivado 重新生成。

## 当前版本要点

- 单周期、非流水线、哈佛结构 CPU。
- PC 复位地址为 `32'h1c000000`，每次 `cpu_en` 有效时执行一条指令。
- 控制器已按修正后的控制信号表输出 `alu_op`、`EXTOP`、寄存器堆选择、写回选择、访存控制和分支跳转控制。
- ALU 使用控制表中的 4 位编码：
  `ADD=0000`、`SUB=0001`、`SLT=0010`、`SLTU=0011`、`SLL=0100`、`SRL=0101`、`SRA=0110`、`AND=0111`、`NOR=1000`、`OR=1001`、`XOR=1010`。
- 立即数扩展由 `EXTOP` 统一控制：
  `001` 为 12 位符号扩展，`010` 为 5 位零扩展，`011` 为 16 位分支偏移扩展，`100` 为 26 位跳转偏移扩展，`101` 为 `lu12i.w` 高位拼接。
- `beq/bne` 由寄存器比较动态产生 `br_taken`，`b/bl/jirl` 为无条件跳转。

## 顶层结构

```text
PC -> inst_rom -> inst_decode -> cpu_control
                         |           |
                         v           v
                    regfile -----> ALU -----> data_ram
                       |            |             |
                       |            v             v
                       +------ branch_unit     writeback
```

## 主要 RTL 模块

- `mini_cpu.v`：CPU 核心顶层，连接取指、译码、控制、寄存器堆、ALU、数据 RAM、写回、分支和调试模块。
- `cpu_control.v`：按修正后的控制信号表生成数据通路选择信号。
- `inst_decode.v`：解析 LoongArch 风格指令字段并识别当前支持的指令。
- `imm_extend.v`：根据 `EXTOP` 输出统一扩展立即数。
- `alu.v`：完成加减、比较、逻辑和移位运算。
- `branch_unit.v`：根据 `br_en/br_op/sel_nextpc/jirl_sel` 生成 `next_pc`。
- `regfile.v`：32 个 32 位通用寄存器，`r0` 恒为 0。
- `store_debug.v`：记录 store 次数、最后一次 store 地址和数据，供仿真/LCD 查看。

## 支持指令

| 指令 | 功能 |
| --- | --- |
| `add.w rd, rj, rk` | `rd = rj + rk` |
| `addi.w rd, rj, imm12` | `rd = rj + sign_extend(imm12)` |
| `sub.w rd, rj, rk` | `rd = rj - rk` |
| `slt rd, rj, rk` | 有符号小于置 1 |
| `sltu rd, rj, rk` | 无符号小于置 1 |
| `slli.w rd, rj, ui5` | 逻辑左移 |
| `srli.w rd, rj, ui5` | 逻辑右移 |
| `srai.w rd, rj, ui5` | 算术右移 |
| `and rd, rj, rk` | 按位与 |
| `or rd, rj, rk` | 按位或 |
| `nor rd, rj, rk` | 按位或非 |
| `xor rd, rj, rk` | 按位异或 |
| `lu12i.w rd, si20` | `rd = si20 << 12` |
| `ld.w rd, rj, imm12` | `rd = data_ram[(rj + sign_extend(imm12))[17:2]]` |
| `st.w rd, rj, imm12` | `data_ram[(rj + sign_extend(imm12))[17:2]] = rd` |
| `beq rj, rd, offs16` | 相等时跳转 |
| `bne rj, rd, offs16` | 不相等时跳转 |
| `b offs26` | 无条件跳转 |
| `bl offs26` | `r1 = PC + 4` 后跳转 |
| `jirl rd, rj, offs16` | `rd = PC + 4`，跳转到 `rj + sign_extend(offs16 << 2)` |

## ROM 程序

### `init.coe`

默认示例程序，覆盖多类指令并保留原工程回归用途。Vivado 仿真 80 步后的关键结果：

```text
STCNT = 2
LSTA  = 0001
LSTD  = 00000014
```

### `init_20inst_verify.coe`

20 条指令专用验证程序，共 66 条指令。该程序把每类指令的结果写入数据 RAM，便于逐项核对。预期最终结果：

```text
STCNT = 23
LSTA  = 0016
LSTD  = 00000014
```

关键 store 结果：

| 地址 | 数据 | 验证项 |
| --- | --- | --- |
| `0000` | `0000000d` | `add.w` |
| `0001` | `00000007` | `sub.w` |
| `0002` | `00000002` | `and` |
| `0003` | `0000000b` | `or` |
| `0004` | `00000009` | `xor` |
| `0005` | `fffffff4` | `nor` |
| `0006` | `00000001` | `slt` |
| `0007` | `00000000` | `sltu` |
| `0008` | `0000000c` | `slli.w` |
| `0009` | `7fffffff` | `srli.w` |
| `000a` | `ffffffff` | `srai.w` |
| `000b` | `12345000` | `lu12i.w` |
| `000c` | `0000000a` | `addi.w/st.w` |
| `000d` | `0000000a` | `ld.w` |
| `000e`-`0012` | `1` 到 `5` | `beq/bne/b` 分支标记 |
| `0013` | `1c0000d8` | `bl` link |
| `0014` | `00000006` | 子程序返回结果 |
| `0015` | `1c0000ec` | `jirl` link |
| `0016` | `00000014` | 最终通过标记 |

## Vivado 仿真

使用 Vivado 2019.2：

```powershell
D:\Vivado\Vivado\2019.2\bin\vivado.bat -mode batch -source run_20inst_sim.tcl
```

工程默认 ROM 初始化仍使用 `init.coe` / `inst_rom.mif`。若要验证 `init_20inst_verify.coe`，可在 Vivado 中把 `inst_rom` 的 coefficient file 改为 `init_20inst_verify.coe` 并重新生成输出，或将该 COE 转成二进制行格式后临时替换 `inst_rom.mif` 再运行仿真。

本版本已完成两轮 Vivado 行为仿真：

- 默认 `init.coe` 回归通过：`STCNT=2`，`LSTA=0001`，`LSTD=00000014`。
- `init_20inst_verify.coe` 通过：`STCNT=23`，`LSTA=0016`，`LSTD=00000014`。

## 打开工程

1. 使用 Vivado 2019.2 打开 `minicpu_basic/minicpu_basic.xpr`。
2. 确认 `lcd_module.dcp` 位于仓库根目录。
3. 若 IP 状态提示需要刷新，重新生成 `inst_rom` 和 `data_ram` 的输出产物。
4. 上板顶层为 `mini_cpu_display`，仿真顶层为 `tb_mini_cpu`。
