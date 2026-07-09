# Final CPU

This repository now uses `final_cpu/` as the main CPU project. The previous
MiniCPU Vivado project has been replaced by the current pipeline BRAM SoC.

## Project Layout

```text
final_cpu/
  mycpu_env/
    myCPU/                         # Pipeline CPU RTL
    func/                          # LoongArch functional test builder
    gettrace/                      # Golden trace generation environment
    soc_verify/soc_bram/           # Main SoC, trace bench, LCD board flow
lcd_module_cell.dcp                # LCD module checkpoint used by board flow
scripts/build_func_exp6.sh         # Functional test build helper
```

The main board top is:

```text
final_cpu/mycpu_env/soc_verify/soc_bram/rtl/soc_lite_lcd_top.v
```

The main non-LCD SoC top is:

```text
final_cpu/mycpu_env/soc_verify/soc_bram/rtl/soc_lite_top.v
```

## Common Commands

Generate a functional test program:

```powershell
wsl -d Ubuntu-24.04 -- bash /mnt/d/CPU_DESIGN/scripts/build_func_exp6.sh 6 final_cpu
```

Generate golden trace:

```powershell
& 'D:\Vivado\Vivado\2019.2\bin\vivado.bat' -mode batch -source 'D:\CPU_DESIGN\final_cpu\mycpu_env\gettrace\run_gettrace_sim.tcl'
```

Run BRAM SoC trace comparison:

```powershell
& 'D:\Vivado\Vivado\2019.2\bin\vivado.bat' -mode batch -source 'D:\CPU_DESIGN\final_cpu\mycpu_env\soc_verify\soc_bram\run_vivado\run_soc_bram_sim.tcl'
```

Run LCD smoke simulation:

```powershell
& 'D:\Vivado\Vivado\2019.2\bin\vivado.bat' -mode batch -source 'D:\CPU_DESIGN\final_cpu\mycpu_env\soc_verify\soc_bram\run_vivado\run_soc_bram_lcd_sim.tcl'
```

Create the LCD board project locally:

```powershell
& 'D:\Vivado\Vivado\2019.2\bin\vivado.bat' -mode batch -source 'D:\CPU_DESIGN\final_cpu\mycpu_env\soc_verify\soc_bram\run_vivado\create_board_project.tcl'
```

The generated `project/`, `project_lcd/`, reports, Vivado caches, and generated
IP products are intentionally not tracked by Git.
