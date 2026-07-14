`timescale 1ns / 1ps

module la32_mem_wb_reg(
    input wire clk, input wire resetn, input wire cpu_en,
    input wire flush, input wire hold, input wire bubble,
    input wire in_valid, input wire [31:0] in_pc, input wire [31:0] in_pc_plus4,
    input wire [31:0] in_inst, input wire [31:0] in_ex_result,
    input wire [31:0] in_load_result, input wire [4:0] in_dest,
    input wire [2:0] in_wb_sel, input wire [1:0] in_counter_sel,
    input wire [13:0] in_csr_num, input wire [31:0] in_csr_wmask,
    input wire [31:0] in_csr_wdata, input wire in_csr_we, input wire in_rf_we,
    input wire in_ertn, input wire in_exc_valid, input wire [5:0] in_ecode,
    input wire [8:0] in_esubcode, input wire [31:0] in_badv,
    output reg out_valid, output reg [31:0] out_pc, output reg [31:0] out_pc_plus4,
    output reg [31:0] out_inst, output reg [31:0] out_ex_result,
    output reg [31:0] out_load_result, output reg [4:0] out_dest,
    output reg [2:0] out_wb_sel, output reg [1:0] out_counter_sel,
    output reg [13:0] out_csr_num, output reg [31:0] out_csr_wmask,
    output reg [31:0] out_csr_wdata, output reg out_csr_we, output reg out_rf_we,
    output reg out_ertn, output reg out_exc_valid, output reg [5:0] out_ecode,
    output reg [8:0] out_esubcode, output reg [31:0] out_badv
);
    always @(posedge clk) begin
        if (!resetn) out_valid <= 0;
        else if (cpu_en) begin
            if (flush) out_valid <= 0;
            else if (hold) out_valid <= out_valid;
            else if (bubble) out_valid <= 0;
            else begin
                out_valid <= in_valid; out_pc <= in_pc; out_pc_plus4 <= in_pc_plus4;
                out_inst <= in_inst; out_ex_result <= in_ex_result;
                out_load_result <= in_load_result; out_dest <= in_dest;
                out_wb_sel <= in_wb_sel; out_counter_sel <= in_counter_sel;
                out_csr_num <= in_csr_num; out_csr_wmask <= in_csr_wmask;
                out_csr_wdata <= in_csr_wdata; out_csr_we <= in_csr_we;
                out_rf_we <= in_rf_we; out_ertn <= in_ertn;
                out_exc_valid <= in_exc_valid; out_ecode <= in_ecode;
                out_esubcode <= in_esubcode; out_badv <= in_badv;
            end
        end
    end
endmodule
