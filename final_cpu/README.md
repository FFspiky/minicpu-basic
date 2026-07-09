# final_cpu

`final_cpu` is the clean standalone EXP23 pipeline CPU SoC used for later LCD,
peripheral, and game work.

## Layout

```text
rtl/cpu/              Pipeline CPU RTL
rtl/soc/              BRAM SoC, LCD top, bridge, confreg
rtl/xilinx_ip/        Vivado IP configuration files only
mem/exp23/            EXP23 RAM initialization images
lib/                  Local LCD DCP dependency
run_vivado/           Board project, LCD simulation, and implementation scripts
```

This directory intentionally does not include the functional-test build system,
golden trace generation, or trace-comparison testbench. Those remain outside
this clean board-oriented SoC.

## Commands

Create or refresh the local LCD board project:

```powershell
& 'D:\Vivado\Vivado\2019.2\bin\vivado.bat' -mode batch -source 'D:\CPU_DESIGN\final_cpu\run_vivado\create_board_project.tcl'
```

Run the LCD smoke simulation:

```powershell
& 'D:\Vivado\Vivado\2019.2\bin\vivado.bat' -mode batch -source 'D:\CPU_DESIGN\final_cpu\run_vivado\run_lcd_sim.tcl'
```

Build a bitstream:

```powershell
& 'D:\Vivado\Vivado\2019.2\bin\vivado.bat' -mode batch -source 'D:\CPU_DESIGN\final_cpu\run_vivado\run_lcd_impl.tcl'
```

Generated Vivado projects, reports, IP products, and logs are ignored by Git.
