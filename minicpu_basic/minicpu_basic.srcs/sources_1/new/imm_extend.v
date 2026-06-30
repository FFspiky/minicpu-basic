`timescale 1ns / 1ps

module imm_extend(
    input  [11:0] imm12,
    input  [15:0] offs16,
    input  [25:0] offs26,
    input  [4:0]  ui5,
    input  [19:0] si20,
    output [31:0] imm12_sext,
    output [31:0] br_offs16,
    output [31:0] br_offs26,
    output [31:0] ui5_zext,
    output [31:0] lu12i_imm
);

    assign imm12_sext = {{20{imm12[11]}}, imm12};
    assign br_offs16  = {{14{offs16[15]}}, offs16, 2'b00};
    assign br_offs26  = {{4{offs26[25]}}, offs26, 2'b00};
    assign ui5_zext   = {27'b0, ui5};
    assign lu12i_imm  = {si20, 12'b0};

endmodule
