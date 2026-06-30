`timescale 1ns / 1ps

// 3-8 译码器
// 将 3 位 alu_op 转换为 8 位独热控制信号
module decoder3_8(
    input  [2:0] in,
    output [7:0] out
);

    assign out = 8'b0000_0001 << in;

endmodule