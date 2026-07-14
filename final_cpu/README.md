# final_cpu：LA32R 可装载演示系统

`final_cpu` 是唯一需要综合和上板的工程。FPGA 比特流中包含流水线 LA32R CPU、统一 RAM、Boot Monitor、UART、NAND 控制器、VGA 程序菜单、赛车显示硬件及固定的 LCD CPU 调试界面。

## 展示流程

```text
C / LA32R 汇编源码
  -> GNU GCC（仅生成汇编文本）
  -> 自研 la32asm（机器码、静态布局、LA32IMG）
  -> UART
  -> Boot Monitor
  -> NAND 程序槽或临时 RAM
  -> 菜单选择并由 final_cpu 执行
```

当前通过JTAG把bitstream写入FPGA配置SRAM，因此每次完全断电后都要重新下载同一
bitstream；如需上电自动配置，应另行烧写板载配置Flash。赛车、流水线EXP16和
其他应用保存在独立NAND中，更换应用不需要重新生成COE、综合或生成bitstream。

## 运行模式与显示

- `MENU`：VGA 显示 `LA32 PROGRAM MANAGER`，PS/2 上下键选择，Enter 运行。
- `GAME`：VGA 显示赛车画面，CPU 连续运行。
- `SELFTEST`：支持 STEP/RUN；VGA 显示 RUNNING、PASSED 或 FAILED。
- LCD 始终显示 PC、指令、提交、写回、流水线 valid/hazard、cycle、step、模式及槽号等 CPU 调试信息，不显示赛车排行榜或游戏状态。
- F12、UART BREAK 或实体复位返回 Boot Monitor。

## 内存布局

| CPU 地址 | 用途 |
|---|---|
| `0x1c000000–0x1c00ffff` | 64 KiB Boot Monitor和异常保留区；MENU时仅Monitor可写运行状态，应用模式下硬件写保护 |
| `0x1c010000–0x1c0effff` | 896 KiB 当前应用代码、数据和BSS |
| `0x1c0f0000–0x1c0fffff` | 64 KiB 用户栈 |

复位入口为 `0x1c000000`，栈顶为 `0x1c100000`。当前无I-cache，装载后不需要cache flush。

## 主要目录

- `rtl/cpu/`：流水线LA32R CPU。
- `rtl/soc/`：SoC、UART、NAND、VGA菜单、PS/2及运行模式。
- `sw/boot_monitor/`：常驻Boot Monitor、LA32IMG校验和NAND槽管理。
- `sw/game/`：赛车C程序。
- `sw/generic/`：通用C程序启动代码、UART微型运行库和示例。
- `sw/selftest/trace_exp16/`：从流水线工程迁入并重定位的完整EXP16 `n1～n58`。
- `tools/la32asm/`：自研汇编器、镜像工具、串口下载器和LA32 Studio。
- `mem/exp23/inst_ram.mif/.coe`：已安装的Boot Monitor启动镜像。

## 构建

### Boot Monitor

```powershell
$repoWsl=(wsl.exe wslpath -a (Get-Location).Path).Trim()
wsl.exe bash -lc "cd '$repoWsl/final_cpu/sw/boot_monitor' && make clean && make install"
```

`make install`只更新工程使用的MIF/COE；不会运行Vivado综合或生成比特流。

### 赛车

```powershell
$env:PYTHONPATH=(Resolve-Path .\final_cpu\tools\la32asm).Path
uv run --python 3.12 python -m la32asm build `
  final_cpu\sw\game\start.S final_cpu\sw\game\racing_game.c `
  -o final_cpu\tools\la32asm\build\racing.la32img `
  --name "Racing Game" --type game
```

### 完整流水线 EXP16 SELFTEST

```powershell
uv run --python 3.12 python final_cpu\sw\selftest\build_exp16.py
```

该命令使用GNU GCC预处理原流水线EXP16汇编宏，机器码、地址布局和LA32IMG全部由自研`la32asm`生成，不调用GNU `as/ld/objcopy`。

### LA32 Studio

```powershell
.\LA32-Studio.cmd
```

页面中的“构建当前 C”会显示C源码、GCC生成的LA32R汇编和自研汇编器机器码清单；“构建并运行”会临时下载镜像到RAM并收集开发板UART输出。内置微型运行库提供`putchar`、`puts`、`print_int`以及支持`%d/%u/%x/%X/%c/%s/%%`的简化`printf`。例如：

```c
int printf(const char *format, ...);
int scanf(const char *format, ...);       // %d/%u/%x: LCD touch numeric input
int lcd_read_int(void);                   // wait for LCD touch confirmation
void lcd_output(int value);               // LCD OUT page + seven-segment display

int main(void) {
    int a = 1, b = 2;
    int c = a + b;
    printf("c = %d\n", c);
    return 0;
}
```

真实运行结果会在网页“板端程序输出”中显示为`c = 3`。输出由`final_cpu`执行程序后经UART返回，并非网页端计算。通用程序运行时VGA显示`GENERIC PROGRAM / RUNNING`，当前不在VGA上绘制字符输出。

## 硬件接口

- CPU/UART时钟：40 MHz；UART线速仍为115200、8N1，分频为347个时钟/位（实际约115274，误差约+0.064%）。RX=`F23`、TX=`H19`；F25是板端DTR输出并保持未使能状态。Studio通过RX上的UART BREAK请求warm reset。
- DB9为RS-232电平，应使用USB转RS-232线，不能直接连接USB-TTL。
- NAND：K9F1G08U0C，16个固定程序槽，坏块扫描、每512字节单比特ECC及双副本目录。
- VGA：菜单、赛车和SELFTEST状态。
- LCD：固定CPU调试页面。

## 已完成验证

- 自研工具链24项单元/集成测试通过，包括多GCC翻译单元局部符号隔离、`.comm` BSS布局、Boot READY同步、短帧目录读取、运行状态回传和可靠复位。
- 赛车GCC汇编经自研汇编后的2740字节机器码与既有GNU结果逐字节一致。
- 完整流水线EXP16 `n1～n58`已生成约532 KiB LA32IMG，并与重定位后的GNU参考机器码进行差分验证。
- 完整EXP16已在`final_cpu`流水线RTL中实际运行通过：`PASS PIPELINE EXP16`，332,206周期后得到双绿灯结果。
- UART独立标准波形仿真：`PASS UART STANDARD 40MHz/115200 CLKS_PER_BIT=347`；TX按时钟逐位检查，RX使用理想115200波形驱动，不再用本工程RX解码本工程TX。
- NAND READ ID、写页、读页、擦除、1/4/2048/2112字节传输、4路byte-enable、边界和超时仿真：`PASS NAND RAW BRAM`。
- NAND页缓冲独立综合为`1 RAMB36E1`，控制器共`425 LUT / 280 FF`，不再使用约1.7万个页缓冲寄存器。
- Boot Monitor集成仿真验证READY、长按键单次移动、下载第2帧DATA返回ACK、完整1072字节LIST回复、同步字节忽略、截断帧超时恢复、MENU写BSS及应用模式boot区写保护。
- 通用C示例已在流水线CPU RTL中实际运行并经UART核对`c = 3`及程序结束标记：`PASS GENERIC C runtime output prefix and EOT`。
- CRC与单比特ECC测试：`PASS CHECKSUM ECC`。
- 全部RTL通过Vivado 2019.2 `xvlog`编译。
- Boot Monitor低于64 KiB保护区限制。

## 稳定版实板验收（2026-07-14）

- 完整非增量实现和bitstream生成成功；最终WNS为`+1.256 ns`、WHS为`+0.052 ns`，时序约束全部满足，routed DRC为0 Error。
- bitstream经JTAG下载到`xc7a200t`成功，下载操作没有修改NAND目录。
- LCD恢复原CPU调试面板，并只增加一个`OUT`和一个`IN`槽位；C程序输出`3`可在LCD和数码管观察。
- F12运行返回菜单正常，不再清空NAND程序槽。
- 赛车镜像在完全断电、重新下载bitstream后仍保持相同名称、2852字节大小、`6ab4f75f`镜像CRC及数据块2，断电后的整镜像VERIFY通过。
- Studio源码启动、免Python便携包、含空格路径、C盘解压、首次WSL工具链安装及C镜像构建均已验证。

稳定bitstream和LA32 Studio便携ZIP作为GitHub Release附件分发；Vivado生成物不纳入Git历史。

## Vivado 实现前门禁（2026-07-13）

本工程的板载100 MHz时钟位于`AC19`，该球脚是
`IO_L14P_T2_SRCC_12`。顶层不再直接用原始`clk`驱动PS/2；PS/2改用
PLL的100 MHz输出，因此PLL输入保持合法的
`AC19 -> IBUF -> PLLE2_ADV`专用路径。不得重新加入
`CLOCK_DEDICATED_ROUTE BACKBONE`，否则Vivado会在`ZHOLD` PLL前共享
插入BUFG并再次触发`REQP-1712`。

并行NAND的原理图管脚为：

| 信号 | FPGA管脚 | 信号 | FPGA管脚 |
|---|---:|---|---:|
| D0 | AC24 | D1 | W21 |
| D2 | U20 | D3 | U19 |
| D4 | V18 | D5 | Y21 |
| D6 | Y20 | D7 | W19 |
| R/B# | AA25 | RE# | AA24 |
| WE# | AA22 | ALE | W20 |
| CLE | V19 | CE# | AB24 |
| WP# | T19 |  |  |

`WP#`由FPGA的`T19`驱动；顶层`nand_wp_n`固定拉高以允许NAND擦除和编程。

在Vivado Tcl Console中先执行：

```tcl
source D:/CPU_DESIGN/final_cpu/run_vivado/prepare_gui_run.tcl
```

该命令只整理工程源文件、启用受版本控制的`board_clock_gen.v`并从工程中移除旧Clock Wizard；PLL随顶层综合，避免旧IP输出产物和重复的`create_clock`约束，不会启动综合或实现。然后在PowerShell中可执行快速门禁：

```powershell
cd D:\CPU_DESIGN\final_cpu
.\run_vivado\preflight\preflight_static.ps1
```

预期输出：

```text
STATIC_PREFLIGHT_PASS ports=114 package_pins=114
```

如需单独复核本次`REQP-1712`根因，可运行约一分钟的时钟专用门禁（只综合和放置PLL小模块，不综合CPU、不生成bitstream）：

```powershell
& 'D:\Vivado\Vivado\2019.2\bin\vivado.bat' -mode batch -nolog -nojournal -notrace `
  -source run_vivado/preflight/validate_board_clock.tcl
```

预期输出`CLOCK_PATH_PASS pll=u_pll clkin_net=clk_in_ibuf`。

硬件构建改用显式的阶段和修改范围，脚本不会再无条件重置两个run。首次建立本轮
NAND新基线时依次执行：

```powershell
cd D:\CPU_DESIGN\final_cpu

$env:BUILD_SCOPE='rtl'
$env:BUILD_TARGET='synth'
& 'D:\vivado\Vivado\2019.2\bin\vivado.bat' -mode batch -nolog -nojournal -notrace `
  -source run_vivado/run_lcd_impl.tcl

$env:BUILD_SCOPE='reuse'
$env:BUILD_TARGET='place'
& 'D:\vivado\Vivado\2019.2\bin\vivado.bat' -mode batch -nolog -nojournal -notrace `
  -source run_vivado/run_lcd_impl.tcl

$env:BUILD_SCOPE='reuse'
$env:BUILD_TARGET='bitstream'
& 'D:\vivado\Vivado\2019.2\bin\vivado.bat' -mode batch -nolog -nojournal -notrace `
  -source run_vivado/run_lcd_impl.tcl
```

`BUILD_SCOPE`含义：

| 值 | 使用场景 |
|---|---|
| `rtl` | RTL或Boot Monitor MIF变化，重置综合和实现 |
| `constraints` | 只改普通管脚/实现约束，保留综合、重置实现；若RTL比综合DCP新会拒绝运行 |
| `reuse` | 同一份输入从综合继续到布局或bitstream，不主动重置 |
| `clean` | PLL、顶层端口、源文件集合或工程结构改变，重建工程/IP |

普通C、汇编、赛车或SELFTEST程序变化只走Studio/UART/NAND，不更新
`mem/exp23/inst_ram.mif`，也不运行Vivado。`prepare_gui_run.tcl`现在只刷新并校验
源文件，不重置run。

新bitstream完成上板验收后，才可在Vivado批处理模式运行：

```tcl
source D:/CPU_DESIGN/final_cpu/run_vivado/capture_incremental_baseline.tcl
```

这会把稳定综合和已布线DCP保存到`run_vivado/checkpoints/`。之后的小型RTL或
外设修改可设置`USE_INCREMENTAL=1`；结构性修改必须回到非增量完整构建。

当前已完成的实现与验收验证：

- 目标封装数据库确认114个顶层端口均有PACKAGE_PIN和IOSTANDARD，且无重复管脚；
- 独立PLL综合、优化、放置及DRC均为0 Error/0 Critical Warning，`REQP-1712`未复现；
- 完整顶层通过`xvlog`编译和`xelab`静态展开；
- LCD内部二分频时钟已约束，`check_timing no_clock`为0；
- `PASS UART`；
- `PASS NAND RAW BRAM`，1/4/2048/2112字节往返、字节写使能、边界、超时和状态清除均通过；
- NAND OOC综合为`425 LUT / 280 FF / 1 RAMB36E1`；
- `PASS CONFREG NAND synchronous BRAM response`；
- `PASS BOOT monitor BSS, key edge, frame 2 ACK and write protection`；
- `PASS PIPELINE EXP16 cycles=332206 pc=1c02027c`；
- 自研工具链24项单元/集成测试全部通过；
- `PASS GENERIC C runtime output prefix and EOT`；
- Boot Monitor为11936字节，低于64 KiB boot区限制。

稳定版已经完成完整综合、布局、布线、物理优化和bitstream生成。最终实现结果为
WNS `+1.256 ns`、WHS `+0.052 ns`、TNS/THS均为0，routed DRC为0 Error；发布时
应使用Release中带SHA256的稳定bitstream，不要混用旧工程目录中的生成文件。

## 自定义C程序的当前边界

Studio已支持编辑、构建和临时运行额外的freestanding C，并同时展示C、GCC汇编、机器码listing和板端UART输出。Boot Monitor按镜像设置栈顶，并将通用程序映射到系统模式3。GNU GCC只执行`C -> LA32R汇编文本`，机器码、静态布局和LA32IMG仍由自研工具生成。

该功能面向不依赖操作系统的简单C程序，不提供完整libc、文件、堆、线程、浮点运行库或系统调用。程序应使用随工程提供的微型输出函数；标准库中未实现的函数无法链接。VGA目前只显示通用程序运行状态，字符结果显示在Studio网页中。若需要完全脱离电脑显示文本，后续版本再增加VGA字符终端和字符显存。
