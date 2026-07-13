`timescale 1ns / 1ps
`include "la32_defs.vh"

module la32_exu(
    input wire clk, input wire resetn, input wire cpu_en,
    input wire valid, input wire exception, input wire is_muldiv,
    input wire ex_advance, input wire kill,
    input wire [31:0] pc, input wire [31:0] raw_src1,
    input wire [31:0] raw_src2, input wire [31:0] ext_imm,
    input wire [4:0] alu_op, input wire [1:0] src1_sel, input wire src2_sel,
    input wire [1:0] forward_src1_sel, input wire [1:0] forward_src2_sel,
    input wire [1:0] forward_store_sel,
    input wire [31:0] mem_forward_data, input wire [31:0] wb_forward_data,
    output reg [31:0] src1_forwarded, output reg [31:0] src2_forwarded,
    output reg [31:0] store_data_forwarded, output reg [31:0] ex_result,
    output wire div_stall
);
    always @(*) begin
        case (forward_src1_sel)
            2'd1: src1_forwarded = mem_forward_data;
            2'd2: src1_forwarded = wb_forward_data;
            default: src1_forwarded = raw_src1;
        endcase
        case (forward_src2_sel)
            2'd1: src2_forwarded = mem_forward_data;
            2'd2: src2_forwarded = wb_forward_data;
            default: src2_forwarded = raw_src2;
        endcase
        case (forward_store_sel)
            2'd1: store_data_forwarded = mem_forward_data;
            2'd2: store_data_forwarded = wb_forward_data;
            default: store_data_forwarded = raw_src2;
        endcase
    end

    wire [31:0] operand1 = src1_sel == `SRC1_PC ? pc :
                           src1_sel == `SRC1_ZERO ? 32'b0 : src1_forwarded;
    wire [31:0] operand2 = src2_sel == `SRC2_IMM ? ext_imm : src2_forwarded;
    wire signed [31:0] signed_op1 = operand1;
    wire signed [31:0] signed_op2 = operand2;

    wire op_mul = alu_op == `ALU_MUL;
    wire op_mulh = alu_op == `ALU_MULH;
    wire op_mulhu = alu_op == `ALU_MULHU;
    wire op_div = alu_op == `ALU_DIV;
    wire op_divu = alu_op == `ALU_DIVU;
    wire op_mod = alu_op == `ALU_MOD;
    wire op_modu = alu_op == `ALU_MODU;
    wire muldiv_busy, muldiv_done;
    wire [31:0] muldiv_result;
    wire muldiv_start = cpu_en && valid && !exception && is_muldiv &&
                        !muldiv_busy && !muldiv_done;
    wire muldiv_clear = cpu_en && valid && is_muldiv && muldiv_done && ex_advance;

    la32_muldiv u_muldiv(
        .clk(clk), .resetn(resetn), .cpu_en(cpu_en), .start(muldiv_start),
        .clear(muldiv_clear), .kill(kill), .src1(src1_forwarded),
        .src2(src2_forwarded), .op_mul_w(op_mul), .op_mulh_w(op_mulh),
        .op_mulh_wu(op_mulhu), .op_div_w(op_div), .op_div_wu(op_divu),
        .op_mod_w(op_mod), .op_mod_wu(op_modu), .busy(muldiv_busy),
        .done(muldiv_done), .result(muldiv_result)
    );
    assign div_stall = valid && !exception && is_muldiv && !muldiv_done;

    always @(*) begin
        case (alu_op)
            `ALU_SUB: ex_result = operand1 - operand2;
            `ALU_SLT: ex_result = {31'b0, signed_op1 < signed_op2};
            `ALU_SLTU: ex_result = {31'b0, operand1 < operand2};
            `ALU_SLL: ex_result = operand1 << operand2[4:0];
            `ALU_SRL: ex_result = operand1 >> operand2[4:0];
            `ALU_SRA: ex_result = signed_op1 >>> operand2[4:0];
            `ALU_AND: ex_result = operand1 & operand2;
            `ALU_NOR: ex_result = ~(operand1 | operand2);
            `ALU_OR: ex_result = operand1 | operand2;
            `ALU_XOR: ex_result = operand1 ^ operand2;
            `ALU_MUL, `ALU_MULH, `ALU_MULHU, `ALU_DIV,
            `ALU_DIVU, `ALU_MOD, `ALU_MODU: ex_result = muldiv_result;
            default: ex_result = operand1 + operand2;
        endcase
    end
endmodule
