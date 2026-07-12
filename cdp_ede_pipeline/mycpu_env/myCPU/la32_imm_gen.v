`timescale 1ns / 1ps

module la32_imm_gen(
    input  wire [31:0] inst,
    output wire [31:0] si12,
    output wire [31:0] ui12,
    output wire [31:0] offs16,
    output wire [31:0] offs26,
    output wire [31:0] si20
);

    assign si12   = {{20{inst[21]}}, inst[21:10]};
    assign ui12   = {20'b0, inst[21:10]};
    assign offs16 = {{14{inst[25]}}, inst[25:10], 2'b0};
    assign offs26 = {{4{inst[9]}}, inst[9:0], inst[25:10], 2'b0};
    assign si20   = {inst[24:5], 12'b0};

endmodule
