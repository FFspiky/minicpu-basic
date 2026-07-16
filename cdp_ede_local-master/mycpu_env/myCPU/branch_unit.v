`timescale 1ns / 1ps

module branch_unit(
    input         br_en,
    input         br_op,
    input         sel_nextpc,
    input         jirl_sel,
    input  [31:0] pc,
    input  [31:0] seq_pc,
    input  [31:0] branch_offs,
    input  [31:0] rdata1,
    input  [31:0] rdata2,
    output [31:0] next_pc,
    output        br_taken
);

    wire cond_taken;

    wire [31:0] branch_base;
    wire [31:0] branch_target;

    assign cond_taken = br_op ? (rdata1 != rdata2) : (rdata1 == rdata2);
    assign br_taken   = br_en & (sel_nextpc ? cond_taken : 1'b1);

    assign branch_base   = jirl_sel ? pc : rdata1;
    assign branch_target = branch_base + branch_offs;

    assign next_pc = br_taken ? branch_target : seq_pc;

endmodule
