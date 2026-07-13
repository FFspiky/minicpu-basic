`ifndef LA32_DEFS_VH
`define LA32_DEFS_VH

`define ECODE_INT 6'h00
`define ECODE_ADE 6'h08
`define ECODE_ALE 6'h09
`define ECODE_SYS 6'h0b
`define ECODE_BRK 6'h0c
`define ECODE_INE 6'h0d

`define EXTOP_SI12   3'd0
`define EXTOP_UI12   3'd1
`define EXTOP_UI5    3'd2
`define EXTOP_SI20   3'd3
`define EXTOP_OFFS16 3'd4
`define EXTOP_OFFS26 3'd5

`define ALU_ADD   5'd0
`define ALU_SUB   5'd1
`define ALU_SLT   5'd2
`define ALU_SLTU  5'd3
`define ALU_SLL   5'd4
`define ALU_SRL   5'd5
`define ALU_SRA   5'd6
`define ALU_AND   5'd7
`define ALU_NOR   5'd8
`define ALU_OR    5'd9
`define ALU_XOR   5'd10
`define ALU_MUL   5'd11
`define ALU_MULH  5'd12
`define ALU_MULHU 5'd13
`define ALU_DIV   5'd14
`define ALU_DIVU  5'd15
`define ALU_MOD   5'd16
`define ALU_MODU  5'd17

`define SRC1_REG  2'd0
`define SRC1_PC   2'd1
`define SRC1_ZERO 2'd2
`define SRC2_REG  1'b0
`define SRC2_IMM  1'b1

`define BR_NONE 4'd0
`define BR_BEQ  4'd1
`define BR_BNE  4'd2
`define BR_BLT  4'd3
`define BR_BGE  4'd4
`define BR_BLTU 4'd5
`define BR_BGEU 4'd6
`define BR_B    4'd7
`define BR_BL   4'd8
`define BR_JIRL 4'd9

`define MEM_NONE 4'd0
`define MEM_LDB  4'd1
`define MEM_LDH  4'd2
`define MEM_LDW  4'd3
`define MEM_LDBU 4'd4
`define MEM_LDHU 4'd5
`define MEM_STB  4'd6
`define MEM_STH  4'd7
`define MEM_STW  4'd8

`define WB_EX      3'd0
`define WB_LOAD    3'd1
`define WB_PC4     3'd2
`define WB_CSR     3'd3
`define WB_CNT_LOW 3'd4
`define WB_CNT_HIGH 3'd5
`define WB_TID     3'd6

`define CSR_NONE 2'd0
`define CSR_READ 2'd1
`define CSR_WRITE 2'd2
`define CSR_XCHG 2'd3

`endif
