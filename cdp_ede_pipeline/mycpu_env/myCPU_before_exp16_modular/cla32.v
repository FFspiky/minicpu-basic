`timescale 1ns / 1ps

module cla32(
    input  [31:0] a,
    input  [31:0] b,
    input         cin,
    output [31:0] sum,
    output        cout
);

    wire P_low;
    wire G_low;
    wire P_high;
    wire G_high;

    wire c16;

    // 低 16 位
    cla16 u_cla16_low(
        .a(a[15:0]),
        .b(b[15:0]),
        .cin(cin),
        .sum(sum[15:0]),
        .cout(),
        .P_group(P_low),
        .G_group(G_low)
    );

    // 16 位块间超前进位
    assign c16 = G_low | (P_low & cin);

    // 高 16 位
    cla16 u_cla16_high(
        .a(a[31:16]),
        .b(b[31:16]),
        .cin(c16),
        .sum(sum[31:16]),
        .cout(),
        .P_group(P_high),
        .G_group(G_high)
    );

    assign cout = G_high | (P_high & c16);

endmodule