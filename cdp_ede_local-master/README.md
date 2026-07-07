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
