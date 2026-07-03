`timescale 1ns / 1ps

module cla16(
    input  [15:0] a,
    input  [15:0] b,
    input         cin,
    output [15:0] sum,
    output        cout,
    output        P_group,
    output        G_group
);

    wire [3:0] P4;
    wire [3:0] G4;
    wire [4:0] c;

    assign c[0] = cin;

    assign c[1] = G4[0] | (P4[0] & c[0]);
    assign c[2] = G4[1] | (P4[1] & G4[0]) | (P4[1] & P4[0] & c[0]);
    assign c[3] = G4[2] | (P4[2] & G4[1]) | (P4[2] & P4[1] & G4[0])
                | (P4[2] & P4[1] & P4[0] & c[0]);
    assign c[4] = G4[3] | (P4[3] & G4[2]) | (P4[3] & P4[2] & G4[1])
                | (P4[3] & P4[2] & P4[1] & G4[0])
                | (P4[3] & P4[2] & P4[1] & P4[0] & c[0]);

    cla4 u_cla4_0(
        .a(a[3:0]),
        .b(b[3:0]),
        .cin(c[0]),
        .sum(sum[3:0]),
        .cout(),
        .P_group(P4[0]),
        .G_group(G4[0])
    );

    cla4 u_cla4_1(
        .a(a[7:4]),
        .b(b[7:4]),
        .cin(c[1]),
        .sum(sum[7:4]),
        .cout(),
        .P_group(P4[1]),
        .G_group(G4[1])
    );

    cla4 u_cla4_2(
        .a(a[11:8]),
        .b(b[11:8]),
        .cin(c[2]),
        .sum(sum[11:8]),
        .cout(),
        .P_group(P4[2]),
        .G_group(G4[2])
    );

    cla4 u_cla4_3(
        .a(a[15:12]),
        .b(b[15:12]),
        .cin(c[3]),
        .sum(sum[15:12]),
        .cout(),
        .P_group(P4[3]),
        .G_group(G4[3])
    );

    assign cout = c[4];

    assign P_group = P4[3] & P4[2] & P4[1] & P4[0];

    assign G_group = G4[3]
                   | (P4[3] & G4[2])
                   | (P4[3] & P4[2] & G4[1])
                   | (P4[3] & P4[2] & P4[1] & G4[0]);

endmodule