# LA32 EXP16 Datapath Alignment

Reference: the user-provided LA32 EXP16 black-box top-level datapath diagram.

## Aligned main path

| Diagram block | RTL implementation |
| --- | --- |
| PC / fetch | `la32_fetch_unit.v` |
| IF/ID | `la32_if_id_reg.v` |
| Control decoder | `la32_decoder.v`, including source-use, destination, load, writeback, and serial controls |
| 2R1W register file | `regfile.v`, with WB commit gating and EX/MEM/WB forwarding |
| Immediate generator | `la32_imm_gen.v` |
| ID/EX | `la32_id_ex_reg.v` |
| EXU | `la32_exu.v`, containing `alu.v`, `la32_branch.v`, and `la32_muldiv.v` |
| EX/MEM | `la32_ex_mem_reg.v` |
| LSU and ALE check | `la32_lsu.v` |
| MEM/WB | `la32_mem_wb_reg.v` |
| Pipeline hazards and holds | `la32_pipeline_control.v` and `la32_forward_unit.v` |
| Exception / ERTN redirect | `la32_exception_control.v` |
| CSR / interrupt | `la32_csr.v`, including `hw_int[7:0] -> ESTAT.IS[9:2]` |
| Stable counter | `la32_stable_counter.v` |
| WB data selection | `la32_wb_select.v` |
| Final commit gating | `la32_commit_control.v` |

## Intentional compatible extensions

The project remains an EXP23-capable superset. TLB translation, TLB
instructions, CACOP, DMW, and related CSRs are retained. They are inactive for
the EXP16 instruction path and do not alter the five-stage datapath shown in
the reference diagram.

At board level, `soc_lite_top.v` ties `hw_int` low because the current board
design has no interrupt-producing peripheral connected to the CPU. The CPU
interface now exposes the complete eight-bit interrupt input required by the
diagram.
