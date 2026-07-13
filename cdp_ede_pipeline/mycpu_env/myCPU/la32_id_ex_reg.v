`timescale 1ns / 1ps

module la32_id_ex_reg(
    input wire clk, input wire resetn, input wire cpu_en,
    input wire flush, input wire hold, input wire bubble,
    input wire set_branch_redirect_sent,
    input wire [31:0] hold_src1_data, input wire [31:0] hold_src2_data,
    input wire in_valid, input wire [31:0] in_pc, input wire [31:0] in_pc_plus4,
    input wire [31:0] in_inst, input wire [31:0] in_src1_data,
    input wire [31:0] in_src2_data, input wire [4:0] in_src1,
    input wire [4:0] in_src2, input wire in_src1_used, input wire in_src2_used,
    input wire [4:0] in_dest, input wire [31:0] in_ext_imm,
    input wire [4:0] in_alu_op, input wire [1:0] in_src1_sel,
    input wire in_src2_sel, input wire [3:0] in_br_op, input wire [3:0] in_mem_op,
    input wire [2:0] in_wb_sel, input wire [1:0] in_csr_op,
    input wire [1:0] in_counter_sel, input wire [13:0] in_csr_num,
    input wire in_rf_we, input wire in_is_load, input wire in_is_csr,
    input wire in_is_counter, input wire in_is_muldiv, input wire in_ertn,
    input wire in_inst_valid, input wire in_exc_valid, input wire [5:0] in_ecode,
    input wire [8:0] in_esubcode, input wire [31:0] in_badv,
    output reg out_valid, output reg [31:0] out_pc, output reg [31:0] out_pc_plus4,
    output reg [31:0] out_inst, output reg [31:0] out_src1_data,
    output reg [31:0] out_src2_data, output reg [4:0] out_src1,
    output reg [4:0] out_src2, output reg out_src1_used, output reg out_src2_used,
    output reg [4:0] out_dest, output reg [31:0] out_ext_imm,
    output reg [4:0] out_alu_op, output reg [1:0] out_src1_sel,
    output reg out_src2_sel, output reg [3:0] out_br_op, output reg [3:0] out_mem_op,
    output reg [2:0] out_wb_sel, output reg [1:0] out_csr_op,
    output reg [1:0] out_counter_sel, output reg [13:0] out_csr_num,
    output reg out_rf_we, output reg out_is_load, output reg out_is_csr,
    output reg out_is_counter, output reg out_is_muldiv, output reg out_ertn,
    output reg out_inst_valid, output reg out_exc_valid, output reg [5:0] out_ecode,
    output reg [8:0] out_esubcode, output reg [31:0] out_badv,
    output reg branch_redirect_sent
);
    always @(posedge clk) begin
        if (!resetn) begin
            out_valid <= 0; branch_redirect_sent <= 0;
        end else if (cpu_en) begin
            if (flush) begin out_valid <= 0; branch_redirect_sent <= 0; end
            else if (hold) begin
                out_src1_data <= hold_src1_data;
                out_src2_data <= hold_src2_data;
                if (set_branch_redirect_sent) branch_redirect_sent <= 1'b1;
            end else if (bubble) begin out_valid <= 0; branch_redirect_sent <= 0; end
            else begin
                out_valid <= in_valid; branch_redirect_sent <= 1'b0;
                out_pc <= in_pc; out_pc_plus4 <= in_pc_plus4; out_inst <= in_inst;
                out_src1_data <= in_src1_data; out_src2_data <= in_src2_data;
                out_src1 <= in_src1; out_src2 <= in_src2;
                out_src1_used <= in_src1_used; out_src2_used <= in_src2_used;
                out_dest <= in_dest; out_ext_imm <= in_ext_imm;
                out_alu_op <= in_alu_op; out_src1_sel <= in_src1_sel;
                out_src2_sel <= in_src2_sel; out_br_op <= in_br_op;
                out_mem_op <= in_mem_op; out_wb_sel <= in_wb_sel;
                out_csr_op <= in_csr_op; out_counter_sel <= in_counter_sel;
                out_csr_num <= in_csr_num; out_rf_we <= in_rf_we;
                out_is_load <= in_is_load; out_is_csr <= in_is_csr;
                out_is_counter <= in_is_counter; out_is_muldiv <= in_is_muldiv;
                out_ertn <= in_ertn; out_inst_valid <= in_inst_valid;
                out_exc_valid <= in_exc_valid; out_ecode <= in_ecode;
                out_esubcode <= in_esubcode; out_badv <= in_badv;
            end
        end
    end
endmodule
