# final_cpu

`final_cpu` is the clean standalone EXP23 pipeline CPU SoC used for later LCD,
peripheral, and game work.

## Layout

```text
rtl/cpu/              Pipeline CPU RTL
rtl/lcd/              MMIO-driven racing renderer, LCD stream, leaderboard
rtl/soc/              BRAM SoC, LCD/VGA tops, PS/2 keyboard, bridge, confreg
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

Run the renderer and LCD frame-snapshot unit simulations:

```powershell
& 'D:\Vivado\Vivado\2019.2\bin\vivado.bat' -mode batch -source 'D:\CPU_DESIGN\final_cpu\run_vivado\run_lcd_unit_sim.tcl'
```

The unit script covers the racing renderer, LCD frame snapshots, PS/2 key
decoding, leaderboard sorting/rendering, and VGA timing/rotation checks.

Build a bitstream:

```powershell
& 'D:\Vivado\Vivado\2019.2\bin\vivado.bat' -mode batch -source 'D:\CPU_DESIGN\final_cpu\run_vivado\run_lcd_impl.tcl'
```

`create_board_project.tcl` synchronizes all RTL files into `sources_1`, closes
and reopens the project to persist the source list in the `.xpr`, and then
leaves the project ready for synthesis. This is required because Vivado
2019.2 has no in-place `save_project` command.

Generated Vivado projects, reports, IP products, and logs are ignored by Git.

## LCD game mode

`soc_lite_lcd_top` defaults to `GAME_LCD=1`, which uses the open RTL game
renderer under `rtl/lcd/`. Set `GAME_LCD=0` to restore the old `lcd_module`
debug display path.

Game state is exposed through `confreg` at `0xbfaf_9000` to `0xbfaf_9080`:

| Address | Register | Layout |
| --- | --- | --- |
| `0xbfaf_9000` | `GAME_CAR` | `[15:4] car_y`, `[1:0] target_lane` |
| `0xbfaf_9010` | `GAME_OBS0` | `[31] active`, `[15:4] x`, `[1:0] lane` |
| `0xbfaf_9020` | `GAME_BONUS` | `[31] active`, `[15:4] x`, `[1:0] lane` |
| `0xbfaf_9030` | `GAME_FLAGS` | `[10:6] level`, `[5] waiting`, `[4:0] control flags` |
| `0xbfaf_9040` | `GAME_SCORE` | `[31:16] Q8 speed`, `[15:0] score` |
| `0xbfaf_9050` | `GAME_COMMIT` | Toggle-backed coherent state commit |
| `0xbfaf_9060` | `LCD_STATUS` | Init, frame toggle, commit acknowledge, controller |
| `0xbfaf_9070` | `GAME_OBS1` | `[31] active`, `[15:4] x`, `[1:0] lane` |
| `0xbfaf_9080` | `GAME_OBS2` | `[31] active`, `[15:4] x`, `[1:0] lane` |

The C source under `sw/game/` writes those registers. Build it from WSL with:

```bash
cd /mnt/d/CPU_DESIGN/final_cpu/sw/game
make install
```

This uses `/opt/loongarch32r/bin/loongarch32r-linux-gnusf-*` and updates
`mem/exp23/inst_ram.mif` plus `mem/exp23/inst_ram.coe`.

The game also writes the decimal score to the legacy seven-segment display
register at `0xbfaf_f050`. After reset it waits for a key, then runs at 60 Hz
with Q8 coordinates, up to three obstacle slots, and a 16-level difficulty
curve. The first ten level changes are compressed to 4, 8, 12, 16, 21, 26,
32, 38, 45, and 52 seconds; level 11 arrives at 60 seconds and level 16 at
180 seconds of active play. Paused and waiting time does not advance the
curve.

The dedicated register at `0xbfaf_f020` lights one additional active-low LED
from left to right on each level increase. Matrix controls are Up for the
temporary speed boost, Down for pause/resume, Left and Right for lane changes,
and the key immediately left of Left (`0x1000`, labelled SW13 on the board)
for soft restart. PS/2 arrow keys provide the same game controls and Space is
the PS/2 soft-restart key. `resetn` remains the board's independent hard reset.

The VGA output carries the racing game. Its active video is mapped with a
counter-clockwise 90-degree rotation. The LCD output carries the leaderboard
with a clockwise 90-degree rotation; the LCD keeps the current top scores
until the next hard reset. The VGA and LCD paths use the 100 MHz display
clock, independently of the CPU clock.

The board constraints include the PS/2 clock/data inputs and the 12-bit VGA
RGB output plus sync signals. The exact mappings are in
`run_vivado/constraints/soc_lite_top.xdc`.
