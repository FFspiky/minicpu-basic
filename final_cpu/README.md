# final_cpu Pipeline SoC

`final_cpu` is the standalone pipeline CPU environment used for future board,
LCD, and game work.

## Contents

```text
mycpu_env/myCPU/                         # Pipeline CPU RTL
mycpu_env/func/                          # Functional-test build system
mycpu_env/gettrace/                      # Golden trace generator
mycpu_env/soc_verify/soc_bram/rtl/       # BRAM SoC and LCD top
mycpu_env/soc_verify/soc_bram/testbench/ # Trace comparison testbench
mycpu_env/soc_verify/soc_bram/run_vivado # Vivado scripts and LCD smoke test
```

`soc_bram` is the main environment. It includes:

- `soc_lite_top.v`: CPU + BRAM/confreg SoC.
- `soc_lite_lcd_top.v`: board/LCD wrapper around `soc_lite_top`.
- `run_vivado/create_board_project.tcl`: recreates local `project_lcd`.
- `run_vivado/run_soc_bram_sim.tcl`: runs trace comparison simulation.
- `run_vivado/run_soc_bram_lcd_sim.tcl`: runs LCD continuous smoke simulation.

The generated Vivado projects `project/` and `project_lcd/` are local build
outputs and are not committed.

## Commands

Build a functional test program:

```powershell
wsl -d Ubuntu-24.04 -- bash /mnt/d/CPU_DESIGN/scripts/build_func_exp6.sh 6 final_cpu
```

Generate golden trace:

```powershell
& 'D:\Vivado\Vivado\2019.2\bin\vivado.bat' -mode batch -source 'D:\CPU_DESIGN\final_cpu\mycpu_env\gettrace\run_gettrace_sim.tcl'
```

Run BRAM trace comparison:

```powershell
& 'D:\Vivado\Vivado\2019.2\bin\vivado.bat' -mode batch -source 'D:\CPU_DESIGN\final_cpu\mycpu_env\soc_verify\soc_bram\run_vivado\run_soc_bram_sim.tcl'
```

Run LCD continuous smoke simulation:

```powershell
& 'D:\Vivado\Vivado\2019.2\bin\vivado.bat' -mode batch -source 'D:\CPU_DESIGN\final_cpu\mycpu_env\soc_verify\soc_bram\run_vivado\run_soc_bram_lcd_sim.tcl'
```

Create the LCD board project:

```powershell
& 'D:\Vivado\Vivado\2019.2\bin\vivado.bat' -mode batch -source 'D:\CPU_DESIGN\final_cpu\mycpu_env\soc_verify\soc_bram\run_vivado\create_board_project.tcl'
```

Use `run_soc_bram_lcd_impl.tcl` only when a full board bitstream is needed.
