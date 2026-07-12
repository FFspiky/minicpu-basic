`timescale 1ns / 1ps

module la32_exu(
    input  wire        clk,
    input  wire        resetn,
    input  wire        cpu_en,
    input  wire [31:0] alu_src1,
    input  wire [31:0] alu_src2,
    input  wire [ 3:0] alu_op,
    output wire [31:0] alu_result,
    input  wire        valid,
    input  wire        exception,
    input  wire        inst_valid,
    input  wire        op_beq,
    input  wire        op_bne,
    input  wire        op_blt,
    input  wire        op_bge,
    input  wire        op_bltu,
    input  wire        op_bgeu,
    input  wire        op_b,
    input  wire        op_bl,
    input  wire        op_jirl,
    input  wire [31:0] pc,
    input  wire [31:0] rj_value,
    input  wire [31:0] rk_value,
    input  wire [31:0] rd_value,
    input  wire [31:0] offs16,
    input  wire [31:0] offs26,
    output wire        branch_taken,
    output wire [31:0] branch_target,
    input  wire        muldiv_start,
    input  wire        muldiv_clear,
    input  wire        muldiv_kill,
    input  wire        op_mul_w,
    input  wire        op_mulh_w,
    input  wire        op_mulh_wu,
    input  wire        op_div_w,
    input  wire        op_div_wu,
    input  wire        op_mod_w,
    input  wire        op_mod_wu,
    output wire        muldiv_busy,
    output wire        muldiv_done,
    output wire [31:0] muldiv_result
);

    alu u_alu(
        .alu_src1(alu_src1),
        .alu_src2(alu_src2),
        .alu_op(alu_op),
        .alu_result(alu_result)
    );

    la32_branch u_branch(
        .valid(valid),
        .exception(exception),
        .inst_valid(inst_valid),
        .op_beq(op_beq),
        .op_bne(op_bne),
        .op_blt(op_blt),
        .op_bge(op_bge),
        .op_bltu(op_bltu),
        .op_bgeu(op_bgeu),
        .op_b(op_b),
        .op_bl(op_bl),
        .op_jirl(op_jirl),
        .pc(pc),
        .rj_value(rj_value),
        .rd_value(rd_value),
        .offs16(offs16),
        .offs26(offs26),
        .taken(branch_taken),
        .target(branch_target)
    );

    la32_muldiv u_muldiv(
        .clk(clk),
        .resetn(resetn),
        .cpu_en(cpu_en),
        .start(muldiv_start),
        .clear(muldiv_clear),
        .kill(muldiv_kill),
        .src1(rj_value),
        .src2(rk_value),
        .op_mul_w(op_mul_w),
        .op_mulh_w(op_mulh_w),
        .op_mulh_wu(op_mulh_wu),
        .op_div_w(op_div_w),
        .op_div_wu(op_div_wu),
        .op_mod_w(op_mod_w),
        .op_mod_wu(op_mod_wu),
        .busy(muldiv_busy),
        .done(muldiv_done),
        .result(muldiv_result)
    );

endmodule
