# CDP/EDE 五级流水线 CPU

本目录是固定的五级流水线 CPU 教学与验证环境。当前正式基线使用独立的流水线 RTL 和 EXP16 功能测试，不通过参数切换为单周期实现。

## 架构范围

- IF、ID、EX、MEM、WB 五级流水；
- 寄存器前递、load-use 停顿、分支重定向和流水线冲刷；
- 乘除法多周期保持；
- 字节、半字和字访存；
- CSR、异常、中断和稳定计数器；
- 统一的 SRAM/debug 接口，顶层为 `mycpu_top`，核心封装为 `mycpu_pipeline`。

`mycpu_env/myCPU/` 中的 RTL 均属于当前 `mycpu_top` 可达层次；旧版单周期模块和废弃 RAM 包装已移除。

## 目录结构

| 路径 | 内容 |
|---|---|
| `mycpu_env/myCPU/` | 五级流水线 CPU RTL |
| `mycpu_env/func/` | EXP16 功能测试源码和 ROM 镜像 |
| `mycpu_env/gettrace/` | golden trace 参考环境 |
| `mycpu_env/soc_verify/soc_bram/` | 主 trace、LCD 和上板环境 |
| `mycpu_env/soc_verify/soc_dram/` | 兼容和参考环境 |
| `minicpu_env/` | 独立 MiniCPU 教学工程，不参与流水线顶层 |

## Trace 对拍

```powershell
& 'D:\Vivado\Vivado\2019.2\bin\vivado.bat' `
  -mode batch -nolog -nojournal -notrace `
  -source 'D:\CPU_DESIGN\cdp_ede_pipeline\mycpu_env\soc_verify\soc_bram\run_vivado\run_soc_bram_sim.tcl'
```

脚本生成只包含 15 个关键 trace 信号的 VCD，并逐条比较 CPU 写回与参考记录。成功标志为：

```text
----PASS: CPU writeback and instruction trace match reference
```

如需重新生成参考 trace：

```powershell
& 'D:\Vivado\Vivado\2019.2\bin\vivado.bat' `
  -mode batch -source 'D:\CPU_DESIGN\cdp_ede_pipeline\mycpu_env\gettrace\run_gettrace_sim.tcl'
```

## 重建 EXP16 镜像

仅在已安装 LA32R 交叉编译工具链时执行：

```powershell
wsl.exe -d Ubuntu-24.04 -- bash -lc `
  "cd /mnt/d/CPU_DESIGN/cdp_ede_pipeline/mycpu_env/func && make clean && make EXP=16"
```

重建后应同步更新 golden trace 并完成全量对拍。

## LCD 仿真与上板

LCD 行为仿真：

```powershell
& 'D:\Vivado\Vivado\2019.2\bin\vivado.bat' `
  -mode batch -source 'D:\CPU_DESIGN\cdp_ede_pipeline\mycpu_env\soc_verify\soc_bram\run_vivado\run_soc_bram_lcd_sim.tcl'
```

创建板级工程：

```powershell
& 'D:\Vivado\Vivado\2019.2\bin\vivado.bat' `
  -mode batch -source 'D:\CPU_DESIGN\cdp_ede_pipeline\mycpu_env\soc_verify\soc_bram\run_vivado\create_board_project.tcl'
```

完整实现和 bitstream：

```powershell
& 'D:\Vivado\Vivado\2019.2\bin\vivado.bat' `
  -mode batch -source 'D:\CPU_DESIGN\cdp_ede_pipeline\mycpu_env\soc_verify\soc_bram\run_vivado\run_soc_bram_lcd_clean_impl.tcl'
```

上板工程依赖仓库根目录的 `lcd_module_cell.dcp`。

## 调试接口

- STEP：运行到下一次有效提交；
- RUN：运行到默认结束 PC `0x1c000100`；
- `PVLD[3:0]`：`{IFID, IDEX, EXMEM, MEMWB}`；
- `HZD[2:0]`：`{load-use stall, branch taken/flush, branch-in-EX}`；
- LCD 页面显示写回、提交、流水级 valid、冒险、周期和运行状态。

Vivado 生成工程、VCD、IP 输出、报告和 bitstream 均为本地产物，不纳入版本管理。
