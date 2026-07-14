`timescale 1ns / 1ps
`include "la32_defs.vh"

module la32_imm_gen(
    input  wire [25:0] imm,
    input  wire [ 2:0] EXTOP,
    output reg  [31:0] ext_imm
);
    always @(*) begin
        case (EXTOP)
            `EXTOP_SI12:   ext_imm = {{20{imm[21]}}, imm[21:10]};
            `EXTOP_UI12:   ext_imm = {20'b0, imm[21:10]};
            `EXTOP_UI5:    ext_imm = {27'b0, imm[14:10]};
            `EXTOP_SI20:   ext_imm = {imm[24:5], 12'b0};
            `EXTOP_OFFS16: ext_imm = {{14{imm[25]}}, imm[25:10], 2'b0};
            `EXTOP_OFFS26: ext_imm = {{4{imm[9]}}, imm[9:0],
                                      imm[25:10], 2'b0};
            default:       ext_imm = 32'b0;
        endcase
    end
endmodule
