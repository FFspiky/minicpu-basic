`timescale 1ns / 1ps

module branch_unit(
    input         inst_beq,
    input         inst_bne,
    input         inst_b,
    input         inst_bl,
    input         inst_jirl,
    input  [31:0] pc,
    input  [31:0] seq_pc,
    input  [31:0] br_offs16,
    input  [31:0] br_offs26,
    input  [31:0] rdata1,
    input  [31:0] rdata2,
    output [31:0] next_pc,
    output        br_taken
);

    wire beq_taken;
    wire bne_taken;
    wire b_taken;
    wire bl_taken;
    wire jirl_taken;

    wire [31:0] pc_branch_target;
    wire [31:0] jirl_target;

    assign beq_taken  = inst_beq && (rdata1 == rdata2);
    assign bne_taken  = inst_bne && (rdata1 != rdata2);
    assign b_taken    = inst_b;
    assign bl_taken   = inst_bl;
    assign jirl_taken = inst_jirl;

    assign br_taken = beq_taken | bne_taken | b_taken | bl_taken | jirl_taken;

    assign pc_branch_target = pc + ((inst_b | inst_bl) ? br_offs26 : br_offs16);
    assign jirl_target      = rdata1 + br_offs16;

    assign next_pc = jirl_taken ? jirl_target :
                     br_taken   ? pc_branch_target :
                                  seq_pc;

endmodule
