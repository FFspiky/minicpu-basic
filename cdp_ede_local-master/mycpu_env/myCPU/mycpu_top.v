`timescale 1ns / 1ps

module mycpu_top(
    input wire clk, input wire resetn, input wire cpu_en,
    output wire inst_sram_en, output wire [3:0] inst_sram_we, output wire [31:0] inst_sram_addr,
    output wire [31:0] inst_sram_wdata, input wire [31:0] inst_sram_rdata,
    output wire data_sram_en, output wire [3:0] data_sram_we, output wire [31:0] data_sram_addr,
    output wire [31:0] data_sram_wdata, input wire [31:0] data_sram_rdata,
    output wire [31:0] debug_wb_pc, output wire [3:0] debug_wb_rf_we,
    output wire [4:0] debug_wb_rf_wnum, output wire [31:0] debug_wb_rf_wdata,
    output wire debug_last_wb_valid, output wire [31:0] debug_last_wb_pc,
    output wire [4:0] debug_last_wb_wnum, output wire [31:0] debug_last_wb_wdata,
    output wire debug_commit_valid, output wire [31:0] debug_commit_pc, output wire [31:0] debug_commit_inst,
    output wire [31:0] debug_fetch_pc, output wire [3:0] debug_pipe_valid, output wire [2:0] debug_pipe_hazard
);
    la32_single_core u_core(.*);
endmodule
