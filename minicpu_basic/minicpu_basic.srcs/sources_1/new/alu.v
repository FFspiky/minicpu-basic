`timescale 1ns / 1ps

module alu(
    input  [31:0] alu_src1,
    input  [31:0] alu_src2,
    input  [11:0] alu_op,
    output [31:0] alu_result
);

    wire op_add;
    wire op_sub;
    wire op_slt;
    wire op_sltu;
    wire op_and;
    wire op_nor;
    wire op_or;
    wire op_xor;
    wire op_sll;
    wire op_srl;
    wire op_sra;
    wire op_lui;

    assign op_add  = alu_op[0];
    assign op_sub  = alu_op[1];
    assign op_slt  = alu_op[2];
    assign op_sltu = alu_op[3];
    assign op_and  = alu_op[4];
    assign op_nor  = alu_op[5];
    assign op_or   = alu_op[6];
    assign op_xor  = alu_op[7];
    assign op_sll  = alu_op[8];
    assign op_srl  = alu_op[9];
    assign op_sra  = alu_op[10];
    assign op_lui  = alu_op[11];

    // sub, slt, and sltu all use src1 - src2.
    wire adder_sub;
    assign adder_sub = op_sub | op_slt | op_sltu;

    // Two's complement subtraction: A - B = A + ~B + 1.
    wire [31:0] adder_b;
    assign adder_b = alu_src2 ^ {32{adder_sub}};

    wire [31:0] adder_result;
    wire        adder_cout;

    // 32-bit carry lookahead adder.
    cla32 u_cla32(
        .a    (alu_src1),
        .b    (adder_b),
        .cin  (adder_sub),
        .sum  (adder_result),
        .cout (adder_cout)
    );

    // Signed less-than comparison.
    wire slt_result;
    assign slt_result =
        (alu_src1[31] & ~alu_src2[31]) |
        ((alu_src1[31] == alu_src2[31]) & adder_result[31]);

    // Unsigned less-than comparison. cout=0 means a borrow occurred.
    wire sltu_result;
    assign sltu_result = ~adder_cout;

    wire [31:0] add_sub_result;
    wire [31:0] slt_result_32;
    wire [31:0] sltu_result_32;
    wire [31:0] and_result;
    wire [31:0] nor_result;
    wire [31:0] or_result;
    wire [31:0] xor_result;
    wire [31:0] sll_result;
    wire [31:0] srl_result;
    wire [31:0] sra_result;
    wire [31:0] lui_result;

    assign add_sub_result = adder_result;
    assign slt_result_32  = {31'b0, slt_result};
    assign sltu_result_32 = {31'b0, sltu_result};
    assign and_result     = alu_src1 & alu_src2;
    assign nor_result     = ~(alu_src1 | alu_src2);
    assign or_result      = alu_src1 | alu_src2;
    assign xor_result     = alu_src1 ^ alu_src2;

    // 32-bit shifts only use the low 5 bits as the shift amount.
    assign sll_result = alu_src1 << alu_src2[4:0];
    assign srl_result = alu_src1 >> alu_src2[4:0];
    assign sra_result = $signed(alu_src1) >>> alu_src2[4:0];
    assign lui_result = alu_src2;

    assign alu_result =
        ({32{op_add }} & add_sub_result) |
        ({32{op_sub }} & add_sub_result) |
        ({32{op_slt }} & slt_result_32 ) |
        ({32{op_sltu}} & sltu_result_32) |
        ({32{op_and }} & and_result    ) |
        ({32{op_nor }} & nor_result    ) |
        ({32{op_or  }} & or_result     ) |
        ({32{op_xor }} & xor_result    ) |
        ({32{op_sll }} & sll_result    ) |
        ({32{op_srl }} & srl_result    ) |
        ({32{op_sra }} & sra_result    ) |
        ({32{op_lui }} & lui_result    );

endmodule
