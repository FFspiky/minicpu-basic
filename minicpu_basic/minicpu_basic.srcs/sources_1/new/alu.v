`timescale 1ns / 1ps

module alu(
    input  [31:0] alu_src1,
    input  [31:0] alu_src2,
    input  [2:0]  alu_op,
    output [31:0] alu_result
);

    wire [7:0] alu_op_d;

    decoder3_8 u_decoder3_8(
        .in  (alu_op),
        .out (alu_op_d)
    );

    wire op_add;
    wire op_sub;
    wire op_slt;
    wire op_sltu;
    wire op_and;
    wire op_or;
    wire op_sll;
    wire op_srl;

    assign op_add  = alu_op_d[0];
    assign op_sub  = alu_op_d[1];
    assign op_slt  = alu_op_d[2];
    assign op_sltu = alu_op_d[3];
    assign op_and  = alu_op_d[4];
    assign op_or   = alu_op_d[5];
    assign op_sll  = alu_op_d[6];
    assign op_srl  = alu_op_d[7];

    // sub、slt、sltu 都需要执行 src1 - src2
    wire adder_sub;
    assign adder_sub = op_sub | op_slt | op_sltu;

    // 减法采用补码：A - B = A + ~B + 1
    wire [31:0] adder_b;
    assign adder_b = alu_src2 ^ {32{adder_sub}};

    wire [31:0] adder_result;
    wire        adder_cout;

    // 调用实验一提高任务完成的 32 位先行进位加法器
    cla32 u_cla32(
        .a    (alu_src1),
        .b    (adder_b),
        .cin  (adder_sub),
        .sum  (adder_result),
        .cout (adder_cout)
    );

    // 有符号小于比较
    wire slt_result;
    assign slt_result =
        (alu_src1[31] & ~alu_src2[31]) |
        ((alu_src1[31] == alu_src2[31]) & adder_result[31]);

    // 无符号小于比较
    // 做 src1 - src2 时，cout=0 表示发生借位
    wire sltu_result;
    assign sltu_result = ~adder_cout;

    wire [31:0] add_sub_result;
    wire [31:0] slt_result_32;
    wire [31:0] sltu_result_32;
    wire [31:0] and_result;
    wire [31:0] or_result;
    wire [31:0] sll_result;
    wire [31:0] srl_result;

    assign add_sub_result = adder_result;
    assign slt_result_32  = {31'b0, slt_result};
    assign sltu_result_32 = {31'b0, sltu_result};
    assign and_result     = alu_src1 & alu_src2;
    assign or_result      = alu_src1 | alu_src2;

    // 32 位数据移位，只需要低 5 位作为移位量
    assign sll_result = alu_src1 << alu_src2[4:0];
    assign srl_result = alu_src1 >> alu_src2[4:0];

    assign alu_result =
        ({32{op_add }} & add_sub_result) |
        ({32{op_sub }} & add_sub_result) |
        ({32{op_slt }} & slt_result_32 ) |
        ({32{op_sltu}} & sltu_result_32) |
        ({32{op_and }} & and_result    ) |
        ({32{op_or  }} & or_result     ) |
        ({32{op_sll }} & sll_result    ) |
        ({32{op_srl }} & srl_result    );

endmodule