# Pipeline EXP16 SELFTEST

正式SELFTEST使用流水线工程的完整上板功能测试EXP16，即`n1～n58`，覆盖基础运算、乘除、分支、字节/半字访存、异常、CSR和计数器指令。源文件位于`trace_exp16/`。

旧流水线镜像不能原样作为程序槽镜像使用，因为其启动桩、`test_finish`和异常向量占用`0x1c000000/0x1c008000`，会覆盖Boot Monitor。本目录中的版本进行了应用化重定位：

- `_start`：`0x1c010000`；
- 异常向量：`0x1c018000`；
- 测试主体`locate`：`0x1c020000`；
- 动态结束PC：`test_finish = 0x1c010100`；
- 保留原NUM_DATA及双红绿灯PASS/FAIL协议；
- 镜像类型为`SELFTEST`，进入后启用STEP/RUN。

## 构建

```powershell
uv run --python 3.12 python final_cpu\sw\selftest\build_exp16.py
```

流程为：GNU GCC只做`.S`宏预处理，之后自研`la32asm`完成全部60个汇编文件的符号解析、指令编码、布局和LA32IMG生成。产物位于`sw/selftest/build/trace_exp16.*`。

构建报告会明确记录：

```json
{
  "tests": "n1-n58",
  "machine_code_generator": "la32asm",
  "gnu_as_ld_objcopy_used": false
}
```

## 运行行为

- 菜单选择后默认处于SELFTEST控制模式；
- STEP运行到下一次有效提交；
- RUN持续到动态结束PC；
- 成功时两组红绿灯写入绿色值`1`，失败写入错误值`2`；
- VGA显示RUNNING/PASSED/FAILED；
- LCD始终保留CPU提交、写回和流水线调试信息；
- F12或复位返回菜单。

## 待验证

完整EXP16已经成功生成约532 KiB LA32IMG，并在`final_cpu`流水线RTL中运行到双绿灯通过：

```text
PASS PIPELINE EXP16 cycles=332206
```

仍需用户在Vivado GUI生成比特流后验证真实开发板上的STEP/RUN、LCD显示、异常返回和板上trace表现。
