`timescale 1ns / 1ps

module cla4(
    input  [3:0] a,
    input  [3:0] b,
    input        cin,
    output [3:0] sum,
    output       cout,
    output       P_group,
    output       G_group
);

    wire [3:0] p;
    wire [3:0] g;
    wire [4:0] c;

    assign p = a ^ b;
    assign g = a & b;

    assign c[0] = cin;

    assign c[1] = g[0] | (p[0] & c[0]);
    assign c[2] = g[1] | (p[1] & g[0]) | (p[1] & p[0] & c[0]);
    assign c[3] = g[2] | (p[2] & g[1]) | (p[2] & p[1] & g[0])
                | (p[2] & p[1] & p[0] & c[0]);
    assign c[4] = g[3] | (p[3] & g[2]) | (p[3] & p[2] & g[1])
                | (p[3] & p[2] & p[1] & g[0])
                | (p[3] & p[2] & p[1] & p[0] & c[0]);

    assign sum  = p ^ c[3:0];
    assign cout = c[4];

    assign P_group = p[3] & p[2] & p[1] & p[0];

    assign G_group = g[3]
                   | (p[3] & g[2])
                   | (p[3] & p[2] & g[1])
                   | (p[3] & p[2] & p[1] & g[0]);

endmodule