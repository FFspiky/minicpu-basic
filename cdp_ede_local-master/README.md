# CDP/EDE Single-Cycle Environment

本目录固定为单周期 CPU 环境。

- CPU RTL：`mycpu_env/myCPU`
- golden trace：`mycpu_env/gettrace`
- trace 对拍：`mycpu_env/soc_verify/soc_dram/run_vivado/project`
- LCD 上板工程：`mycpu_env/soc_verify/soc_dram/run_vivado/project_lcd`

常用命令：

```powershell
wsl -d Ubuntu-24.04 -- bash /mnt/d/CPU_DESIGN/scripts/build_func_exp6.sh 16 cdp_ede_local-master
& 'D:\Vivado\Vivado\2019.2\bin\vivado.bat' -mode batch -source 'D:\CPU_DESIGN\cdp_ede_local-master\mycpu_env\gettrace\run_gettrace_sim.tcl'
& 'D:\Vivado\Vivado\2019.2\bin\vivado.bat' -mode batch -source 'D:\CPU_DESIGN\cdp_ede_local-master\mycpu_env\soc_verify\soc_dram\run_vivado\run_soc_dram_sim.tcl'
```

## BRAM board path

- `soc_bram` is now the main single-cycle trace and board environment.
- `soc_dram` remains as a compatibility/reference environment.
- The CPU follows the reviewed single-cycle datapath: decoder, control, immediate extension, two-read-port register file, ALU, branch unit, LSU, CSR/exception controller, counter, and iterative mul/div unit.
- Ordinary EXP16 instructions retire in one clock; synchronous BRAM loads use one explicit wait state and iterative multiply/divide operations hold the core until completion.
- Default and acceptance testing for this single-cycle environment is EXP16 (`n1`~`n58`).
- EXP8/EXP9 are for pipeline no-NOP hazard validation; an EXP9 log in this directory is not evidence of pipeline-style hazard handling.
- The datapath review and known diagram corrections are documented in `mycpu_env/myCPU/SINGLE_CYCLE_DATAPATH_AUDIT.md`.
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
