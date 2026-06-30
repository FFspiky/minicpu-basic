`timescale 1ns / 1ps

module branch_unit(
    input         inst_bne,
    input  [31:0] pc,
    input  [31:0] seq_pc,
    input  [31:0] br_offs,
    input  [31:0] rdata1,
    input  [31:0] rdata2,
    output [31:0] next_pc,
    output        br_taken
);

    wire [31:0] br_target;

    assign br_taken = (inst_bne == 1'b1) && (rdata1 != rdata2);
    assign br_target = pc + br_offs;

    assign next_pc = (br_taken == 1'b1) ? br_target : seq_pc;

endmodule
