# final_cpu

`final_cpu` is the clean standalone EXP23 pipeline CPU SoC used for later LCD,
peripheral, and game work.

## Layout

```text
rtl/cpu/              Pipeline CPU RTL
rtl/lcd/              MMIO-driven racing LCD renderer
rtl/soc/              BRAM SoC, LCD top, bridge, confreg
rtl/xilinx_ip/        Vivado IP configuration files only
mem/exp23/            EXP23 RAM initialization images
lib/                  Local LCD DCP dependency
run_vivado/           Board project, LCD simulation, and implementation scripts
sw/game/              Bare-metal racing game MMIO source
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

## LCD game mode

`soc_lite_lcd_top` defaults to `GAME_LCD=1`, which uses the open RTL game
renderer under `rtl/lcd/`. Set `GAME_LCD=0` to restore the old `lcd_module`
debug display path.

Game state is exposed through `confreg` at `0xbfaf_9000` to `0xbfaf_9060`.
The C source under `sw/game/` writes those registers. Build it from WSL with:

```bash
cd /mnt/d/CPU_DESIGN/final_cpu/sw/game
make install
```

This uses `/opt/loongarch32r/bin/loongarch32r-linux-gnusf-*` and updates
`mem/exp23/inst_ram.mif` plus `mem/exp23/inst_ram.coe`.
