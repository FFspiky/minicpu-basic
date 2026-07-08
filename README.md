# LoongArch CPU Design

本仓库基于 Vivado 2019.2。当前已经把单周期 CPU 和五级流水线 CPU 拆成两个独立环境：

- `cdp_ede_local-master/`：单周期 CPU 环境
- `cdp_ede_pipeline/`：五级流水线 CPU 环境
- `minicpu_basic/`：旧 MiniCPU Vivado 工程，不参与当前 trace/上板流程

两个 CPU 环境内部仍保持同样的工程结构：

- `mycpu_env/gettrace/`：生成 `golden_trace.txt`
- `mycpu_env/soc_verify/soc_dram/run_vivado/project/`：trace 对拍 Vivado 工程
- `mycpu_env/soc_verify/soc_dram/run_vivado/project_lcd/`：LCD 上板 Vivado 工程

CPU 类型现在由目录决定，不再通过 `USE_PIPELINE` 或 `CPU_USE_PIPELINE` 参数切换。

## 环境要求

- Windows 11
- WSL2 + Ubuntu 24.04
- Vivado 2019.2
- LA32R 交叉编译工具链

本机 Vivado 默认路径：

```text
D:\Vivado\Vivado\2019.2\bin\vivado.bat
```

## 生成功能测试程序

默认生成 EXP6 到单周期环境：

```powershell
wsl -d Ubuntu-24.04 -- bash /mnt/d/CPU_DESIGN/scripts/build_func_exp6.sh
```

指定实验号和环境目录：

```powershell
wsl -d Ubuntu-24.04 -- bash /mnt/d/CPU_DESIGN/scripts/build_func_exp6.sh 6 cdp_ede_local-master
wsl -d Ubuntu-24.04 -- bash /mnt/d/CPU_DESIGN/scripts/build_func_exp6.sh 6 cdp_ede_pipeline
wsl -d Ubuntu-24.04 -- bash /mnt/d/CPU_DESIGN/scripts/build_func_exp6.sh 8 cdp_ede_pipeline
wsl -d Ubuntu-24.04 -- bash /mnt/d/CPU_DESIGN/scripts/build_func_exp6.sh 9 cdp_ede_pipeline
```

生成结果位于对应环境的：

```text
mycpu_env/func/obj/
```

## 单周期 CPU

单周期环境路径：

```text
D:\CPU_DESIGN\cdp_ede_local-master
```

生成 golden trace：

```powershell
& 'D:\Vivado\Vivado\2019.2\bin\vivado.bat' -mode batch -source 'D:\CPU_DESIGN\cdp_ede_local-master\mycpu_env\gettrace\run_gettrace_sim.tcl'
```

跑 trace 对拍：

```powershell
& 'D:\Vivado\Vivado\2019.2\bin\vivado.bat' -mode batch -source 'D:\CPU_DESIGN\cdp_ede_local-master\mycpu_env\soc_verify\soc_dram\run_vivado\run_soc_dram_sim.tcl'
```

trace GUI 工程：

```text
D:\CPU_DESIGN\cdp_ede_local-master\mycpu_env\soc_verify\soc_dram\run_vivado\project\loongson.xpr
```

上板工程生成脚本：

```powershell
& 'D:\Vivado\Vivado\2019.2\bin\vivado.bat' -mode batch -source 'D:\CPU_DESIGN\cdp_ede_local-master\mycpu_env\soc_verify\soc_dram\run_vivado\create_board_project.tcl'
```

上板 GUI 工程：

```text
D:\CPU_DESIGN\cdp_ede_local-master\mycpu_env\soc_verify\soc_dram\run_vivado\project_lcd\loongson_lcd.xpr
```

完整生成 bitstream 的脚本：

```powershell
& 'D:\Vivado\Vivado\2019.2\bin\vivado.bat' -mode batch -source 'D:\CPU_DESIGN\cdp_ede_local-master\mycpu_env\soc_verify\soc_dram\run_vivado\run_soc_dram_lcd_impl.tcl'
```

## 五级流水线 CPU

流水线环境路径：

```text
D:\CPU_DESIGN\cdp_ede_pipeline
```

生成 golden trace：

```powershell
& 'D:\Vivado\Vivado\2019.2\bin\vivado.bat' -mode batch -source 'D:\CPU_DESIGN\cdp_ede_pipeline\mycpu_env\gettrace\run_gettrace_sim.tcl'
```

跑 trace 对拍：

```powershell
& 'D:\Vivado\Vivado\2019.2\bin\vivado.bat' -mode batch -source 'D:\CPU_DESIGN\cdp_ede_pipeline\mycpu_env\soc_verify\soc_dram\run_vivado\run_soc_dram_sim.tcl'
```

trace GUI 工程：

```text
D:\CPU_DESIGN\cdp_ede_pipeline\mycpu_env\soc_verify\soc_dram\run_vivado\project\loongson.xpr
```

上板工程生成脚本：

```powershell
& 'D:\Vivado\Vivado\2019.2\bin\vivado.bat' -mode batch -source 'D:\CPU_DESIGN\cdp_ede_pipeline\mycpu_env\soc_verify\soc_dram\run_vivado\create_board_project.tcl'
```

上板 GUI 工程：

```text
D:\CPU_DESIGN\cdp_ede_pipeline\mycpu_env\soc_verify\soc_dram\run_vivado\project_lcd\loongson_lcd.xpr
```

完整生成 bitstream 的脚本：

```powershell
& 'D:\Vivado\Vivado\2019.2\bin\vivado.bat' -mode batch -source 'D:\CPU_DESIGN\cdp_ede_pipeline\mycpu_env\soc_verify\soc_dram\run_vivado\run_soc_dram_lcd_impl.tcl'
```

## 当前状态

- 单周期环境只保留单周期 `mycpu_top`。
- 流水线环境只保留流水线 `mycpu_top` + `mycpu_pipeline`。
- 两个环境的 trace 工程和上板工程互相独立，均由各自目录下的脚本生成。
- `project/`、`project_lcd/` 和 Vivado/IP 中间产物不纳入版本管理。

## Single-cycle board verification notes

- `cdp_ede_local-master/` is the single-cycle CPU environment.
- Single-cycle board top now uses BRAM: `D:\CPU_DESIGN\cdp_ede_local-master\mycpu_env\soc_verify\soc_bram\rtl\soc_lite_lcd_top.v`.
- `soc_dram` is kept as a compatibility/reference environment.
- Single-cycle acceptance uses EXP6. EXP8/EXP9 are reserved for the pipeline no-NOP hazard validation path.
- Single-cycle BRAM trace script:

```powershell
& 'D:\Vivado\Vivado\2019.2\bin\vivado.bat' -mode batch -source 'D:\CPU_DESIGN\cdp_ede_local-master\mycpu_env\soc_verify\soc_bram\run_vivado\run_soc_bram_sim.tcl'
```

- Single-cycle BRAM board project script:

```powershell
& 'D:\Vivado\Vivado\2019.2\bin\vivado.bat' -mode batch -source 'D:\CPU_DESIGN\cdp_ede_local-master\mycpu_env\soc_verify\soc_bram\run_vivado\create_board_project.tcl'
```

- Single-cycle BRAM LCD smoke simulation:

```powershell
& 'D:\Vivado\Vivado\2019.2\bin\vivado.bat' -mode batch -source 'D:\CPU_DESIGN\cdp_ede_local-master\mycpu_env\soc_verify\soc_bram\run_vivado\run_soc_bram_lcd_sim.tcl'
```

- Single-cycle BRAM bitstream script, to be run manually when needed:

```powershell
& 'D:\Vivado\Vivado\2019.2\bin\vivado.bat' -mode batch -source 'D:\CPU_DESIGN\cdp_ede_local-master\mycpu_env\soc_verify\soc_bram\run_vivado\run_soc_bram_lcd_impl.tcl'
```

- If the EXP program is changed before board generation, run the clean implementation script once:

```powershell
& 'D:\Vivado\Vivado\2019.2\bin\vivado.bat' -mode batch -source 'D:\CPU_DESIGN\cdp_ede_local-master\mycpu_env\soc_verify\soc_bram\run_vivado\run_soc_bram_lcd_clean_impl.tcl'
```

- STEP runs until one instruction commits; `ld.w` may use one extra BRAM wait cycle.
- RUN stops when `END_PC = 32'h1c000100` commits.
- Timing reports are written to `D:\CPU_DESIGN\cdp_ede_local-master\mycpu_env\soc_verify\soc_bram\run_vivado\reports`.
- LCD pages: `WBPC`, `INST`, `Rxx`, `WRPC`, `STEP`, `CYCL`, `IFPC`, `CMTPC`, `CMTI`, `PVLD`, `HZD`, `NUM`, `MODE`, `RUN`, `DONE`, `SW`.
- For single-cycle BRAM, `PVLD[1:0]` shows `{load-wait, execute-valid}` and `HZD[0]` shows `load-wait`.

## Pipeline board verification notes

- `cdp_ede_local-master/` is the single-cycle CPU environment.
- `cdp_ede_pipeline/` is the five-stage pipeline CPU environment.
- CPU type is selected by directory, not by `USE_PIPELINE` or `CPU_USE_PIPELINE`.
- Pipeline board top now uses BRAM: `D:\CPU_DESIGN\cdp_ede_pipeline\mycpu_env\soc_verify\soc_bram\rtl\soc_lite_lcd_top.v`.
- `soc_dram` is kept only as a compatibility/reference environment.
- Pipeline BRAM trace script:

```powershell
& 'D:\Vivado\Vivado\2019.2\bin\vivado.bat' -mode batch -source 'D:\CPU_DESIGN\cdp_ede_pipeline\mycpu_env\soc_verify\soc_bram\run_vivado\run_soc_bram_sim.tcl'
```

- Pipeline BRAM board project script:

```powershell
& 'D:\Vivado\Vivado\2019.2\bin\vivado.bat' -mode batch -source 'D:\CPU_DESIGN\cdp_ede_pipeline\mycpu_env\soc_verify\soc_bram\run_vivado\create_board_project.tcl'
```

- Pipeline BRAM LCD smoke simulation:

```powershell
& 'D:\Vivado\Vivado\2019.2\bin\vivado.bat' -mode batch -source 'D:\CPU_DESIGN\cdp_ede_pipeline\mycpu_env\soc_verify\soc_bram\run_vivado\run_soc_bram_lcd_sim.tcl'
```

- Pipeline BRAM bitstream script, to be run manually when needed:

```powershell
& 'D:\Vivado\Vivado\2019.2\bin\vivado.bat' -mode batch -source 'D:\CPU_DESIGN\cdp_ede_pipeline\mycpu_env\soc_verify\soc_bram\run_vivado\run_soc_bram_lcd_impl.tcl'
```

- If the EXP program is changed before board generation, run the clean implementation script once:

```powershell
& 'D:\Vivado\Vivado\2019.2\bin\vivado.bat' -mode batch -source 'D:\CPU_DESIGN\cdp_ede_pipeline\mycpu_env\soc_verify\soc_bram\run_vivado\run_soc_bram_lcd_clean_impl.tcl'
```

- In board single-step mode, STEP runs the CPU until one instruction commits.
- In RUN mode, DONE is asserted when `END_PC = 32'h1c000100` commits.
- `END_PC` remains `32'h1c000100` by default; the LCD smoke test may override it to a short-running commit PC.
- The BRAM implementation script writes timing reports to `D:\CPU_DESIGN\cdp_ede_pipeline\mycpu_env\soc_verify\soc_bram\run_vivado\reports`.
- LCD pages: `WBPC`, `INST`, `Rxx`, `WRPC`, `STEP`, `CYCL`, `IFPC`, `CMTPC`, `CMTI`, `PVLD`, `HZD`, `NUM`, `MODE`, `RUN`, `DONE`, `SW`.
- `PVLD[3:0]` shows `{IFID, IDEX, EXMEM, MEMWB}`.
- `HZD[2:0]` shows `{load-use stall, branch taken/flush, branch-in-EX}`.
