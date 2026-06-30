`timescale 1ns / 1ps

module imm_extend(
    input  [11:0] imm12,
    input  [15:0] offs16,
    output [31:0] imm12_sext,
    output [31:0] br_offs
);

    assign imm12_sext = {{20{imm12[11]}}, imm12};
    assign br_offs    = {{14{offs16[15]}}, offs16, 2'b00};

endmodule
