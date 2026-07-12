# 单周期数据通路纠错与 RTL 对应规范

检查对象：`C:\Users\DELL\Downloads\70左右指令单周期.drawio`（2026-07-10 版本）。

目标范围：EXP16，即功能测试 `n1` 到 `n58`。普通 ALU、跳转、访存、CSR、异常和计数器指令按单周期数据通路执行；同步 BRAM 读和迭代乘除法允许显式等待。

## 图中需要修正或补充的地方

1. **ALU 细化图不完整**
   - 必须补齐 `slt`、`sltu`、`nor`。
   - 左移、逻辑右移和算术右移必须由不同的 `alu_op` 区分。
   - `lu12i.w` 可以走立即数旁路；`pcaddu12i` 必须选择 PC 作为 ALU 源 1。

2. **缺少乘除法数据通路**
   - EXP16 需要 `mul.w`、`mulh.w`、`mulh.wu`、`div.w`、`div.wu`、`mod.w`、`mod.wu`。
   - 若采用迭代单元，必须增加 `start/busy/done`，等待期间冻结 PC 和取指，并只在完成时写回一次。

3. **立即数扩展类型不完整**
   - `si12`：`addi.w`、`slti`、`sltui`、load/store 地址；其中 `sltui` 是无符号比较，但立即数仍是符号扩展的 `si12`。
   - `ui12`：`andi`、`ori`、`xori`。
   - `ui5`：立即数移位。
   - `si20 << 12`：`lu12i.w`、`pcaddu12i`。
   - `offs16 << 2` 和 `offs26 << 2`：分支/跳转。

4. **分支判断不能只依赖 Zero**
   - 条件分支必须支持 `eq`、`ne`、有符号 `<`/`>=`、无符号 `<`/`>=` 六种比较。
   - `beq/bne/blt/bge/bltu/bgeu` 的第二操作数来自 `rd`，不是 `rk`。
   - `jirl` 的基址是 `rj`；其他分支和 `b/bl` 的基址是 PC。

5. **寄存器堆应按图使用第二读地址 MUX**
   - 读口 1 固定读取 `rj`。
   - 读口 2 在 `rk` 与 `rd` 之间选择：ALU-R/乘除使用 `rk`；store、条件分支、CSRWR/CSRXCHG 使用 `rd`。
   - `bl` 的目的寄存器固定为 `r1`；`rdcntid` 的目的字段是 `rj`；其他普通写回使用 `rd`。

6. **访存写使能不是单比特**
   - `data_ram_we` 必须是 4 位字节写掩码。
   - `st.b/st.h` 需要按 `addr[1:0]` 生成掩码和移位后的写数据。
   - `ld.b/ld.h` 做符号扩展，`ld.bu/ld.hu` 做零扩展。
   - 半字和字访问必须检查对齐并产生 ALE；异常访问不能产生 RAM 写副作用。

7. **图中的 overflow 异常输入应删除**
   - EXP16 的 `n49` 是定时器中断，不是整数溢出异常。
   - EXP16 需要的 ECODE 为 INT(0x00)、ADEF(0x08)、ALE(0x09)、SYS(0x0b)、BRK(0x0c)、INE(0x0d)。

8. **异常控制器必须明确优先级和副作用抑制**
   - 中断在指令边界进入；随后检查 ADEF、INE、SYS、BRK、ALE。
   - 异常发生时保存当前 PC 到 ERA，必要时写 BADV，并跳到 CSR.EENTRY。
   - `ertn` 跳到 ERA，并由 CSR 恢复 CRMD.PLV/IE。
   - 异常周期必须屏蔽 GPR、数据 RAM 和普通 CSR 写副作用。

9. **CSR 方框内部语义不能省略**
   - EXP16 至少需要 CRMD、PRMD、ECFG、ESTAT、ERA、BADV、EENTRY、SAVE0~3、TID、TCFG、TVAL、TICLR。
   - `csrwr`：新值来自 `rd` 的旧值，旧 CSR 值写回 `rd`。
   - `csrxchg`：`rj` 是掩码，`rd` 的旧值是写数据，旧 CSR 值写回 `rd`。
   - 中断条件为 `CRMD.IE & |(ESTAT.IS & ECFG.LIE)`。

10. **计数器通路需要区分 stable counter 与 TID**
    - `rdcntvl.w`/`rdcntvh.w` 读取全局 64 位稳定计数器的低/高 32 位。
    - `rdcntid` 读取 CSR.TID，并写入指令的 `rj` 字段。
    - TCFG/TVAL/TICLR 组成定时器中断逻辑，不是 stable counter 的索引。

11. **同步存储器不能按纯组合 RAM 处理**
    - 板级 BRAM 的读数据下一拍有效，因此 load 需要一个等待状态。
    - 取指采用“执行当前指令时预取 next PC”的方式；等待期间保持已预取指令并禁止重复请求。

12. **图外散落草图不是主数据通路的一部分**
    - 负坐标的跳转草图、右侧 ALU 草图和下方寄存器堆草图应移到独立页面或标注为子模块细化图，避免被误认为并行硬件实例。
    - 主图的写回 MUX、分支 MUX 和子模块细化图必须使用一致的选择编码。

## RTL 模块映射

| 图中模块 | RTL 模块 | 说明 |
| --- | --- | --- |
| 指令译码器 | `la32_decoder` | 产生逐指令译码线和寄存器字段 |
| 控制器 | `cpu_control` | 产生所有 MUX、ALU、分支、写回和存储器控制信号 |
| 扩展器 | `imm_extend` | 统一生成当前指令使用的立即数 |
| 寄存器堆 | `regfile` | 2 读 1 写，第二读地址由 `rk/rd` MUX 选择 |
| ALU | `alu` | 普通算术、逻辑、比较和移位 |
| 分支目标地址/判断 | `branch_unit` | 六种条件比较、PC/rj 基址和 next PC MUX |
| 数据存储器适配 | `la32_lsu` | 地址检查、写掩码、写数据和 load 扩展 |
| CSR 寄存器 | `la32_csr` | CSR、异常状态、稳定计数器和定时器 |
| 异常控制器 | `la32_exception_ctrl` | 异常优先级、ECODE 和 BADV 选择 |
| 乘除法器 | `la32_muldiv` | 多周期乘除法及等待握手 |
| 顶层数据通路 | `la32_single_core` | 连接上述模块并管理 PC/load/muldiv 等待状态 |
