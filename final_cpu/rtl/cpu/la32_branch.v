`timescale 1ns / 1ps

module la32_branch(
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
    input  wire [31:0] rd_value,
    input  wire [31:0] offs16,
    input  wire [31:0] offs26,
    output wire        taken,
    output wire [31:0] target
);

    wire signed [31:0] signed_rj = rj_value;
    wire signed [31:0] signed_rd = rd_value;
    wire conditional_taken =
        (op_beq  & (rj_value == rd_value)) |
        (op_bne  & (rj_value != rd_value)) |
        (op_blt  & (signed_rj < signed_rd)) |
        (op_bge  & (signed_rj >= signed_rd)) |
        (op_bltu & (rj_value < rd_value)) |
        (op_bgeu & (rj_value >= rd_value));

    assign taken = valid & !exception & inst_valid &
                   (op_b | op_bl | op_jirl | conditional_taken);
    assign target = op_jirl ? (rj_value + offs16) :
                    (op_b | op_bl) ? (pc + offs26) :
                    (pc + offs16);

endmodule
