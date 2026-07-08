`timescale 1ns / 1ps

module inst_decode(
    input  [31:0] inst,

    output [4:0]  rd,
    output [4:0]  rj,
    output [4:0]  rk,
    output [11:0] imm12,
    output [15:0] offs16,
    output [4:0]  ui5,
    output [19:0] si20,
    output [25:0] offs26,

    output        inst_add_w,
    output        inst_addi_w,
    output        inst_ld_w,
    output        inst_st_w,
    output        inst_bne,
    output        inst_sub_w,
    output        inst_and,
    output        inst_or,
    output        inst_beq,
    output        inst_b,
    output        inst_bl,
    output        inst_jirl,
    output        inst_slt,
    output        inst_sltu,
    output        inst_slli_w,
    output        inst_srli_w,
    output        inst_srai_w,
    output        inst_lu12i_w,
    output        inst_nor,
    output        inst_xor
);

    wire [5:0] op_31_26;
    wire [3:0] op_25_22;
    wire [1:0] op_21_20;
    wire [4:0] op_19_15;

    assign rd     = inst[4:0];
    assign rj     = inst[9:5];
    assign rk     = inst[14:10];
    assign imm12  = inst[21:10];
    assign offs16 = inst[25:10];
    assign ui5    = inst[14:10];
    assign si20   = inst[24:5];
    assign offs26 = {inst[9:0], inst[25:10]};

    assign op_31_26 = inst[31:26];
    assign op_25_22 = inst[25:22];
    assign op_21_20 = inst[21:20];
    assign op_19_15 = inst[19:15];

    assign inst_add_w  = (op_31_26 == 6'b000000) &&
                         (op_25_22 == 4'b0000)   &&
                         (op_21_20 == 2'b01)     &&
                         (op_19_15 == 5'b00000);

    assign inst_sub_w  = (op_31_26 == 6'b000000) &&
                         (op_25_22 == 4'b0000)   &&
                         (op_21_20 == 2'b01)     &&
                         (op_19_15 == 5'b00010);

    assign inst_slt    = (op_31_26 == 6'b000000) &&
                         (op_25_22 == 4'b0000)   &&
                         (op_21_20 == 2'b01)     &&
                         (op_19_15 == 5'b00100);

    assign inst_sltu   = (op_31_26 == 6'b000000) &&
                         (op_25_22 == 4'b0000)   &&
                         (op_21_20 == 2'b01)     &&
                         (op_19_15 == 5'b00101);

    assign inst_nor    = (op_31_26 == 6'b000000) &&
                         (op_25_22 == 4'b0000)   &&
                         (op_21_20 == 2'b01)     &&
                         (op_19_15 == 5'b01000);

    assign inst_and    = (op_31_26 == 6'b000000) &&
                         (op_25_22 == 4'b0000)   &&
                         (op_21_20 == 2'b01)     &&
                         (op_19_15 == 5'b01001);

    assign inst_or     = (op_31_26 == 6'b000000) &&
                         (op_25_22 == 4'b0000)   &&
                         (op_21_20 == 2'b01)     &&
                         (op_19_15 == 5'b01010);

    assign inst_xor    = (op_31_26 == 6'b000000) &&
                         (op_25_22 == 4'b0000)   &&
                         (op_21_20 == 2'b01)     &&
                         (op_19_15 == 5'b01011);

    assign inst_slli_w = (op_31_26 == 6'b000000) &&
                         (op_25_22 == 4'b0001)   &&
                         (op_21_20 == 2'b00)     &&
                         (op_19_15 == 5'b00001);

    assign inst_srli_w = (op_31_26 == 6'b000000) &&
                         (op_25_22 == 4'b0001)   &&
                         (op_21_20 == 2'b00)     &&
                         (op_19_15 == 5'b01001);

    assign inst_srai_w = (op_31_26 == 6'b000000) &&
                         (op_25_22 == 4'b0001)   &&
                         (op_21_20 == 2'b00)     &&
                         (op_19_15 == 5'b10001);

    assign inst_addi_w = (op_31_26 == 6'b000000) &&
                         (op_25_22 == 4'b1010);

    assign inst_ld_w   = (op_31_26 == 6'b001010) &&
                         (op_25_22 == 4'b0010);

    assign inst_st_w   = (op_31_26 == 6'b001010) &&
                         (op_25_22 == 4'b0110);

    assign inst_bne    = (op_31_26 == 6'b010111);

    assign inst_lu12i_w = (inst[31:25] == 7'b0001010);

    assign inst_beq     = (op_31_26 == 6'b010110);
    assign inst_b       = (op_31_26 == 6'b010100);
    assign inst_bl      = (op_31_26 == 6'b010101);
    assign inst_jirl    = (op_31_26 == 6'b010011);

endmodule
