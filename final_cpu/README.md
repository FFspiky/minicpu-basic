# final_cpu 板级演示系统

`final_cpu` 是本仓库的独立板级主工程。系统在一颗 FPGA 中集成五级流水线 LA32R CPU、Boot Monitor、统一 RAM、UART、NAND、VGA 菜单、PS/2 输入和 LCD CPU 调试界面，并通过 LA32 Studio 支持 C/汇编构建、临时运行和 NAND 程序槽管理。

## 稳定版本

课程展示和实板验收应使用 [GitHub Releases](https://github.com/FFspiky/minicpu-basic/releases/latest) 中发布的稳定 bitstream。仓库脚本生成的本地 `.bit` 文件是开发候选物，只有完成时序、DRC、断电重配置、NAND 保持、UART 下载、菜单返回和应用运行复核后才能作为正式发布资产。

FPGA 配置 SRAM 在完全断电后会丢失 bitstream，需要重新通过 JTAG 下载；NAND 中已安装的应用不会因此被擦除。

## 系统结构

```text
C / LA32R 汇编源码
  -> GNU GCC（C 仅编译为 LA32R 汇编文本）
  -> la32asm（汇编、静态布局和 LA32IMG）
  -> UART / LA32 Studio
  -> Boot Monitor
  -> 临时 RAM 或 NAND 程序槽
  -> 流水线 CPU 执行
```

运行模式：

- `MENU`：VGA 程序菜单，使用 PS/2 上下键选择、Enter 启动；
- `GAME`：运行赛车应用并输出 VGA 画面；
- `SELFTEST`：运行完整 EXP16，支持 STEP/RUN 和 PASS/FAIL 状态；
- `GENERIC`：运行用户 C/汇编程序，字符输出通过 UART 返回 Studio；
- F12、UART BREAK 或实体复位返回 Boot Monitor。

LCD 保持为 CPU 调试界面，显示 PC、指令、提交、写回、流水级 valid/hazard、周期、运行模式以及一个数值输入和输出区域。

## 目录结构

| 路径 | 内容 |
|---|---|
| `rtl/cpu/` | 当前五级流水线 CPU RTL |
| `rtl/soc/` | SoC、RAM 总线、UART、NAND、VGA 和 PS/2 外设 |
| `rtl/lcd/` | LCD/VGA 共用的游戏状态和像素渲染模块 |
| `rtl/xilinx_ip/` | 受版本控制的 XCI 配置；生成物不提交 |
| `run_vivado/` | 工程创建、仿真、实现和硬件前置检查脚本 |
| `sw/boot_monitor/` | 常驻 Boot Monitor 与 NAND 槽管理 |
| `sw/game/` | 赛车应用 |
| `sw/generic/` | freestanding C 启动代码和微型运行库 |
| `sw/selftest/` | 重定位后的完整流水线 EXP16 |
| `tools/la32asm/` | 汇编器、镜像工具、串口协议和 LA32 Studio |
| `mem/exp23/` | Boot Monitor 启动 ROM 的 MIF/COE |
| `lib/lcd_module_cell.dcp` | 综合使用的 LCD 预综合检查点 |

## 内存布局

| CPU 地址 | 用途 |
|---|---|
| `0x1c000000`～`0x1c00ffff` | 64 KiB Boot Monitor 和异常保留区 |
| `0x1c010000`～`0x1c0effff` | 896 KiB 当前应用代码、数据和 BSS |
| `0x1c0f0000`～`0x1c0fffff` | 64 KiB 用户栈 |

复位入口为 `0x1c000000`，栈顶为 `0x1c100000`。应用模式下硬件保护 Boot Monitor 区域。

## LA32 Studio

在仓库根目录运行：

```powershell
.\LA32-Studio.cmd
```

浏览器界面支持：

- 编辑和构建 freestanding C；
- 直接编辑 LA32R 汇编；
- 查看 GCC 汇编、机器码清单、BIN、MIF、COE 和 LA32IMG；
- 临时下载到 RAM 并读取开发板真实 UART 输出；
- 安装、列出、校验、删除和格式化 NAND 程序槽；
- 构建赛车和完整流水线 EXP16。

无本机 Python 的电脑应使用 Release 中的 LA32 Studio 便携包。命令行工具和协议说明见 [`tools/la32asm/README.md`](tools/la32asm/README.md)。

## 软件构建

### Boot Monitor

在仓库根目录执行：

```powershell
$repoWsl = (wsl.exe wslpath -a (Get-Location).Path).Trim()
wsl.exe bash -lc "cd '$repoWsl/final_cpu/sw/boot_monitor' && make clean && make install"
```

`make install` 只更新 `mem/exp23/` 中的 MIF/COE，不运行 Vivado。

### 赛车镜像

```powershell
$env:PYTHONPATH = (Resolve-Path .\final_cpu\tools\la32asm).Path
python -m la32asm build `
  final_cpu\sw\game\start.S final_cpu\sw\game\racing_game.c `
  -o final_cpu\tools\la32asm\build\racing.la32img `
  --name 'Racing Game' --type game
```

### EXP16 SELFTEST

```powershell
$env:PYTHONPATH = (Resolve-Path .\final_cpu\tools\la32asm).Path
python final_cpu\sw\selftest\build_exp16.py
```

详细布局和运行协议见 [`sw/selftest/README.md`](sw/selftest/README.md)。

## 验证

### Python 工具链测试

```powershell
$env:PYTHONPATH = (Resolve-Path .\final_cpu\tools\la32asm).Path
python -m unittest discover -s final_cpu\tools\la32asm\tests -p 'test_*.py' -v
```

### 静态硬件门禁

```powershell
cd D:\CPU_DESIGN\final_cpu
.\run_vivado\preflight\preflight_static.ps1
```

预期输出：

```text
STATIC_PREFLIGHT_PASS ports=115 package_pins=115
```

独立时钟路径验证：

```powershell
& 'D:\Vivado\Vivado\2019.2\bin\vivado.bat' `
  -mode batch -nolog -nojournal -notrace `
  -source run_vivado\preflight\validate_board_clock.tcl
```

### 行为仿真

```powershell
& 'D:\Vivado\Vivado\2019.2\bin\vivado.bat' `
  -mode batch -nolog -nojournal -notrace `
  -source D:\CPU_DESIGN\final_cpu\run_vivado\run_lcd_unit_sim.tcl
```

发布前还应运行 Boot Monitor、EXP16、通用 C、UART、NAND 和板级顶层回归脚本，并检查每个脚本的 PASS/FAIL 输出。Vivado 进程返回 0 不等价于测试用例 PASS。

## Vivado 工程与实现

创建或刷新 GUI 工程：

```powershell
& 'D:\Vivado\Vivado\2019.2\bin\vivado.bat' `
  -mode batch -source D:\CPU_DESIGN\final_cpu\run_vivado\create_board_project.tcl
```

完整干净实现：

```powershell
$env:BUILD_SCOPE = 'clean'
$env:BUILD_TARGET = 'bitstream'
& 'D:\Vivado\Vivado\2019.2\bin\vivado.bat' `
  -mode batch -nolog -nojournal -notrace `
  -source D:\CPU_DESIGN\final_cpu\run_vivado\run_lcd_impl.tcl
```

可用构建范围：

| `BUILD_SCOPE` | 用途 |
|---|---|
| `rtl` | RTL 或 Boot Monitor MIF 变化，重跑综合和实现 |
| `constraints` | 仅约束变化，保留有效综合结果 |
| `reuse` | 使用同一输入继续现有 run |
| `clean` | 顶层、PLL、源文件集合或工程结构变化，重建工程和 IP |

`BUILD_TARGET` 可取 `synth`、`place` 或 `bitstream`。只有已验收的基线才应启用增量实现。

## 硬件接口

- 板载输入时钟：100 MHz，CPU/UART 工作时钟：50 MHz；
- UART：115200 8N1，RX=`F23`、TX=`H19`，DB9 为 RS-232 电平；
- NAND：K9F1G08U0C，提供程序槽、坏块处理、ECC 和双副本目录；
- VGA：菜单、赛车和 SELFTEST 状态；
- PS/2：菜单和游戏输入；
- LCD：固定 CPU 调试界面。

DB9 必须配合 USB 转 RS-232 线，不能直接连接 USB-TTL。

## 版本管理边界

`run_vivado/project*`、Vivado/IP 生成物、报告、检查点、`.bit`、软件构建目录和便携包均不提交。受版本控制的 `lib/lcd_module_cell.dcp` 是必要构建输入，应保留。正式发布资产和校验值通过 GitHub Release 分发。
