`timescale 1ns / 1ps
`include "la32_defs.vh"

module la32_branch(
    input wire valid, input wire exception, input wire [3:0] br_op,
    input wire [31:0] pc, input wire [31:0] src1_value,
    input wire [31:0] src2_value, input wire [31:0] ext_imm,
    output wire taken, output wire [31:0] target
);
    wire signed [31:0] s1 = src1_value;
    wire signed [31:0] s2 = src2_value;
    reg condition;
    always @(*) begin
        case (br_op)
            `BR_BEQ: condition = src1_value == src2_value;
            `BR_BNE: condition = src1_value != src2_value;
            `BR_BLT: condition = s1 < s2;
            `BR_BGE: condition = s1 >= s2;
            `BR_BLTU: condition = src1_value < src2_value;
            `BR_BGEU: condition = src1_value >= src2_value;
            `BR_B, `BR_BL, `BR_JIRL: condition = 1'b1;
            default: condition = 1'b0;
        endcase
    end
    assign taken = valid && !exception && (br_op != `BR_NONE) && condition;
    assign target = br_op == `BR_JIRL ? src1_value + ext_imm : pc + ext_imm;
endmodule
