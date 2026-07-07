# CDP/EDE Pipeline Environment

本目录固定为五级流水线 CPU 环境。

- CPU RTL：`mycpu_env/myCPU`
- golden trace：`mycpu_env/gettrace`
- trace 对拍：`mycpu_env/soc_verify/soc_dram/run_vivado/project`
- LCD 上板工程：`mycpu_env/soc_verify/soc_dram/run_vivado/project_lcd`

常用命令：

```powershell
wsl -d Ubuntu-24.04 -- bash /mnt/d/CPU_DESIGN/scripts/build_func_exp6.sh 6 cdp_ede_pipeline
& 'D:\Vivado\Vivado\2019.2\bin\vivado.bat' -mode batch -source 'D:\CPU_DESIGN\cdp_ede_pipeline\mycpu_env\gettrace\run_gettrace_sim.tcl'
& 'D:\Vivado\Vivado\2019.2\bin\vivado.bat' -mode batch -source 'D:\CPU_DESIGN\cdp_ede_pipeline\mycpu_env\soc_verify\soc_dram\run_vivado\run_soc_dram_sim.tcl'
```

## Board verification and LCD

- This directory is the pipeline CPU environment.
- The single-cycle CPU remains in `D:\CPU_DESIGN\cdp_ede_local-master`.
- CPU type is selected by directory; this environment always builds `mycpu_top` + `mycpu_pipeline`.
- Board top: `mycpu_env\soc_verify\soc_dram\rtl\soc_lite_lcd_top.v`.
- Board project script:

```powershell
& 'D:\Vivado\Vivado\2019.2\bin\vivado.bat' -mode batch -source 'D:\CPU_DESIGN\cdp_ede_pipeline\mycpu_env\soc_verify\soc_dram\run_vivado\create_board_project.tcl'
```

- LCD smoke simulation:

```powershell
& 'D:\Vivado\Vivado\2019.2\bin\vivado.bat' -mode batch -source 'D:\CPU_DESIGN\cdp_ede_pipeline\mycpu_env\soc_verify\soc_dram\run_vivado\run_soc_dram_lcd_sim.tcl'
```

- STEP mode runs until one instruction commits.
- RUN mode stops when `END_PC = 32'h1c000100` commits.
- `END_PC` is a top-level parameter with default `32'h1c000100`; the LCD smoke test overrides it to a short-running commit PC.
- LCD pages: `WBPC`, `INST`, `Rxx`, `WRPC`, `STEP`, `CYCL`, `IFPC`, `CMTPC`, `CMTI`, `PVLD`, `HZD`, `NUM`, `MODE`, `RUN`, `DONE`, `SW`.
- `PVLD[3:0]` shows `{IFID, IDEX, EXMEM, MEMWB}`.
- `HZD[2:0]` shows `{load-use stall, branch taken/flush, branch-in-EX}`.
