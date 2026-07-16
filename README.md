# LoongArch CPU Design

本仓库包含三个相互独立的 LoongArch 32 位 CPU 工程：用于 EXP6 教学验证的单周期 CPU、用于完整功能测试的五级流水线 CPU，以及集成 Boot Monitor、UART、NAND、VGA、LCD 和应用加载能力的 `final_cpu` 板级系统。

## 工程组成

| 目录 | 定位 | 验收范围 |
|---|---|---|
| [`cdp_ede_local-master/`](cdp_ede_local-master/) | 单周期 CPU 教学与对拍环境 | EXP6，20 个功能测试点 |
| [`cdp_ede_pipeline/`](cdp_ede_pipeline/) | 五级流水线 CPU 教学与对拍环境 | EXP16，`n1`～`n58` |
| [`final_cpu/`](final_cpu/) | 独立板级演示系统与后续开发主线 | 流水线 CPU、Boot Monitor、程序装载和板载外设 |

CPU 类型由目录决定，不通过宏或参数在单周期与流水线之间切换。两个 CDP/EDE 环境保留各自的功能测试、golden trace、仿真和上板工程；`final_cpu` 不依赖这两个目录参与综合。

## 环境要求

- Windows 10/11；
- Vivado 2019.2；
- WSL2（建议 Ubuntu 24.04）；
- 重建 CDP/EDE 测试镜像或编译 C 程序时需要 LA32R 交叉编译工具链；
- 使用 LA32 Studio 时需要 Python 3.10+，或使用 GitHub Release 中的便携版。

以下命令假定仓库位于 `D:\CPU_DESIGN`。路径不同时，请替换为实际绝对路径。

```powershell
$Vivado = 'D:\Vivado\Vivado\2019.2\bin\vivado.bat'
```

## 快速验证

### 单周期 EXP6

仓库已提交 EXP6 指令镜像和对应 golden trace，可直接运行 BRAM 对拍：

```powershell
& $Vivado -mode batch -nolog -nojournal -notrace `
  -source 'D:\CPU_DESIGN\cdp_ede_local-master\mycpu_env\soc_verify\soc_bram\run_vivado\run_soc_bram_sim.tcl'
```

通过时会依次报告 20 个功能测试点 PASS，并以 `----PASS!!!` 结束。

### 五级流水线

```powershell
& $Vivado -mode batch -nolog -nojournal -notrace `
  -source 'D:\CPU_DESIGN\cdp_ede_pipeline\mycpu_env\soc_verify\soc_bram\run_vivado\run_soc_bram_sim.tcl'
```

该仿真比较 CPU 写回和指令提交轨迹，成功时输出 `CPU writeback and instruction trace match reference`。

### final_cpu

静态硬件门禁：

```powershell
cd D:\CPU_DESIGN\final_cpu
.\run_vivado\preflight\preflight_static.ps1
```

预期输出：

```text
STATIC_PREFLIGHT_PASS ports=115 package_pins=115
```

LA32 工具链测试：

```powershell
$env:PYTHONPATH = (Resolve-Path .\final_cpu\tools\la32asm).Path
python -m unittest discover -s final_cpu\tools\la32asm\tests -p 'test_*.py' -v
```

更完整的构建、仿真和上板说明见 [`final_cpu/README.md`](final_cpu/README.md)。

## LCD 检查点依赖

- 根目录 `lcd_module_cell.dcp` 由两个 CDP/EDE 环境的 BRAM/DRAM 上板工程共同引用；
- `final_cpu/lib/lcd_module_cell.dcp` 仅供 `final_cpu` 使用；
- 两个文件均为构建输入，不是可随意删除的 Vivado 中间产物。

## 分支与发布

- `main` 保存经过整理的主线源码；
- `tree` 用作集成和验证分支，完成验证后再合入 `main`；
- `.bit`、Vivado 生成目录、便携运行时和本地输出不提交到 Git；
- 展示和上板应优先使用 [GitHub Releases](https://github.com/FFspiky/minicpu-basic/releases/latest) 中经过验收的 bitstream 和 LA32 Studio 便携包。

发布文件边界和操作流程见 [`GITHUB_RELEASE.md`](GITHUB_RELEASE.md)。

## 版本库约定

`project/`、`project_lcd/`、`.Xil/`、`*.runs/`、`*.sim/`、`*.bit`、日志、报告和软件构建目录均由脚本生成并通过 `.gitignore` 排除。提交前应确认 `git status` 中只包含预期的源码、约束、测试资产和文档变更。
