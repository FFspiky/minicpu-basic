# Pipeline EXP16 SELFTEST

本目录保存 `final_cpu` 使用的完整流水线 EXP16 自检程序，覆盖 `n1`～`n58`。测试范围包括基础算术与逻辑、乘除、分支、字节/半字/字访存、异常、CSR 和稳定计数器。

## 与原始功能测试的差异

原始流水线测试占用 Boot Monitor 地址空间，不能直接作为程序槽镜像。本版本已应用化重定位：

| 项目 | 地址或行为 |
|---|---|
| `_start` | `0x1c010000` |
| 异常向量 | `0x1c018000` |
| 测试主体 `locate` | `0x1c020000` |
| 动态结束 PC | `test_finish = 0x1c010100` |
| 结果协议 | 保留 NUM_DATA 和双红绿灯 PASS/FAIL |
| 镜像类型 | `SELFTEST`，支持 STEP/RUN |

## 构建

在仓库根目录执行：

```powershell
$env:PYTHONPATH = (Resolve-Path .\final_cpu\tools\la32asm).Path
python final_cpu\sw\selftest\build_exp16.py
```

GNU GCC 仅负责预处理 `.S` 宏；符号解析、指令编码、静态布局和 LA32IMG 生成均由 `la32asm` 完成，不调用 GNU `as`、`ld` 或 `objcopy`。产物位于 `final_cpu/sw/selftest/build/`。

构建报告应包含：

```json
{
  "tests": "n1-n58",
  "machine_code_generator": "la32asm",
  "gnu_as_ld_objcopy_used": false
}
```

## 运行协议

- 菜单启动 SELFTEST 后进入自检控制模式；
- STEP 运行到下一次有效提交；
- RUN 持续到动态结束 PC；
- 成功时两组红绿灯写入绿色值 `1`，失败写入错误值 `2`；
- VGA 显示 `RUNNING`、`PASSED` 或 `FAILED`；
- LCD 保持显示 CPU 提交、写回和流水线调试信息；
- F12、UART BREAK 或复位返回 Boot Monitor。

## 验收要求

发布前必须完成以下检查：

1. `build_exp16.py` 成功生成镜像和构建报告；
2. Python 工具链测试通过；
3. `run_exp16_runtime.tcl` 的 RTL 回归输出 `PASS PIPELINE EXP16`；
4. 实板 STEP/RUN、LCD、VGA PASS/FAIL、异常返回和菜单返回正常；
5. NAND 安装、整镜像校验和断电保持通过。

本目录只保存源码和构建脚本；`build/` 为生成目录，不纳入版本管理。
