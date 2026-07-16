# CDP/EDE 单周期 CPU

本目录是固定的单周期 CPU 教学与验证环境，当前正式基线面向 EXP6。CPU RTL、测试镜像、golden trace、行为仿真和上板工程均在本目录内维护，不与流水线工程混用。

## 功能范围

- EXP6 共 20 个功能测试点；
- 支持基础算术、逻辑、移位、加载/存储和分支跳转指令；
- 普通指令按单周期数据通路执行；
- 同步 BRAM 的 `ld.w` 使用一个显式等待周期完成数据返回；
- 不提供流水线前递、冒险检测或多级 valid 控制。

EXP8、EXP9 和 EXP16 的流水线冒险或扩展指令验收不属于本工程范围。

## 目录结构

| 路径 | 内容 |
|---|---|
| `mycpu_env/myCPU/` | 单周期 CPU RTL，顶层为 `mycpu_top` |
| `mycpu_env/func/` | 功能测试源码和已提交的 EXP6 ROM 镜像 |
| `mycpu_env/gettrace/` | golden trace 生成环境 |
| `mycpu_env/soc_verify/soc_bram/` | 主验证与上板环境 |
| `mycpu_env/soc_verify/soc_dram/` | 兼容和参考环境 |

主板级顶层为 `mycpu_env/soc_verify/soc_bram/rtl/soc_lite_lcd_top.v`。

## EXP6 对拍

仓库中的 `mycpu_env/func/obj/inst_ram.mif`、`inst_ram.coe` 和 `mycpu_env/gettrace/golden_trace.txt` 已组成一致的 EXP6 基线，可直接运行：

```powershell
& 'D:\Vivado\Vivado\2019.2\bin\vivado.bat' `
  -mode batch -nolog -nojournal -notrace `
  -source 'D:\CPU_DESIGN\cdp_ede_local-master\mycpu_env\soc_verify\soc_bram\run_vivado\run_soc_bram_sim.tcl'
```

通过标准为 20 个功能测试点全部 PASS，最终输出：

```text
----PASS!!!
```

如需重新生成 golden trace：

```powershell
& 'D:\Vivado\Vivado\2019.2\bin\vivado.bat' `
  -mode batch -source 'D:\CPU_DESIGN\cdp_ede_local-master\mycpu_env\gettrace\run_gettrace_sim.tcl'
```

## 重建 EXP6 镜像

仅在已安装 LA32R 交叉编译工具链时执行：

```powershell
wsl.exe -d Ubuntu-24.04 -- bash -lc `
  "cd /mnt/d/CPU_DESIGN/cdp_ede_local-master/mycpu_env/func && make clean && make EXP=6"
```

重建镜像后必须同步重建 golden trace，并重新运行 BRAM 对拍；不要提交镜像与 trace 不匹配的状态。

## LCD 仿真与上板

LCD 行为仿真：

```powershell
& 'D:\Vivado\Vivado\2019.2\bin\vivado.bat' `
  -mode batch -source 'D:\CPU_DESIGN\cdp_ede_local-master\mycpu_env\soc_verify\soc_bram\run_vivado\run_soc_bram_lcd_sim.tcl'
```

创建可在 Vivado GUI 中打开的工程：

```powershell
& 'D:\Vivado\Vivado\2019.2\bin\vivado.bat' `
  -mode batch -source 'D:\CPU_DESIGN\cdp_ede_local-master\mycpu_env\soc_verify\soc_bram\run_vivado\create_board_project.tcl'
```

完整实现和 bitstream：

```powershell
& 'D:\Vivado\Vivado\2019.2\bin\vivado.bat' `
  -mode batch -source 'D:\CPU_DESIGN\cdp_ede_local-master\mycpu_env\soc_verify\soc_bram\run_vivado\run_soc_bram_lcd_clean_impl.tcl'
```

上板工程依赖仓库根目录的 `lcd_module_cell.dcp`。该文件是受版本控制的构建输入。

## 调试接口

- STEP：运行到下一次有效提交；
- RUN：运行到默认结束 PC `0x1c000100`；
- `PVLD[1:0]`：`{load-wait, execute-valid}`；
- `HZD[0]`：同步加载等待；
- LCD 页面包含写回 PC、指令、寄存器、提交、周期、运行状态和开关输入。

Vivado 生成的工程、IP 输出、波形、报告和 bitstream 均为本地产物，不纳入版本管理。
