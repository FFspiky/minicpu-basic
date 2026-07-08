# CDP/EDE Single-Cycle Environment

本目录固定为单周期 CPU 环境。

- CPU RTL：`mycpu_env/myCPU`
- golden trace：`mycpu_env/gettrace`
- trace 对拍：`mycpu_env/soc_verify/soc_dram/run_vivado/project`
- LCD 上板工程：`mycpu_env/soc_verify/soc_dram/run_vivado/project_lcd`

常用命令：

```powershell
wsl -d Ubuntu-24.04 -- bash /mnt/d/CPU_DESIGN/scripts/build_func_exp6.sh 6 cdp_ede_local-master
& 'D:\Vivado\Vivado\2019.2\bin\vivado.bat' -mode batch -source 'D:\CPU_DESIGN\cdp_ede_local-master\mycpu_env\gettrace\run_gettrace_sim.tcl'
& 'D:\Vivado\Vivado\2019.2\bin\vivado.bat' -mode batch -source 'D:\CPU_DESIGN\cdp_ede_local-master\mycpu_env\soc_verify\soc_dram\run_vivado\run_soc_dram_sim.tcl'
```

## BRAM board path

- `soc_bram` is now the main single-cycle trace and board environment.
- `soc_dram` remains as a compatibility/reference environment.
- The CPU keeps the single-cycle datapath, with BRAM request/response alignment and one extra wait cycle for `ld.w`.
- Default and acceptance testing for this single-cycle environment is EXP6, not EXP9.
- EXP8/EXP9 are for pipeline no-NOP hazard validation; an EXP9 log in this directory is not evidence of pipeline-style hazard handling.
- BRAM trace simulation:

```powershell
& 'D:\Vivado\Vivado\2019.2\bin\vivado.bat' -mode batch -source 'D:\CPU_DESIGN\cdp_ede_local-master\mycpu_env\soc_verify\soc_bram\run_vivado\run_soc_bram_sim.tcl'
```

- BRAM LCD smoke simulation:

```powershell
& 'D:\Vivado\Vivado\2019.2\bin\vivado.bat' -mode batch -source 'D:\CPU_DESIGN\cdp_ede_local-master\mycpu_env\soc_verify\soc_bram\run_vivado\run_soc_bram_lcd_sim.tcl'
```

- BRAM board project:

```powershell
& 'D:\Vivado\Vivado\2019.2\bin\vivado.bat' -mode batch -source 'D:\CPU_DESIGN\cdp_ede_local-master\mycpu_env\soc_verify\soc_bram\run_vivado\create_board_project.tcl'
```

- BRAM bitstream script, intended to be run manually:

```powershell
& 'D:\Vivado\Vivado\2019.2\bin\vivado.bat' -mode batch -source 'D:\CPU_DESIGN\cdp_ede_local-master\mycpu_env\soc_verify\soc_bram\run_vivado\run_soc_bram_lcd_impl.tcl'
```

- If the EXP program is changed before board generation, use `run_soc_bram_lcd_clean_impl.tcl` once to rebuild the project and generated IP products cleanly.
- STEP mode runs until one instruction commits; RUN mode stops when `END_PC = 32'h1c000100` commits.
- Timing reports are written to `mycpu_env\soc_verify\soc_bram\run_vivado\reports`.
