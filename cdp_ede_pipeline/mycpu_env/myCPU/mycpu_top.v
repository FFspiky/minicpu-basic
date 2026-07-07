`timescale 1ns / 1ps

module mycpu_top(
    input  wire        clk,
    input  wire        resetn,
    input  wire        cpu_en,

    output wire        inst_sram_we,
    output wire [31:0] inst_sram_addr,
    output wire [31:0] inst_sram_wdata,
    input  wire [31:0] inst_sram_rdata,

    output wire        data_sram_we,
    output wire [31:0] data_sram_addr,
    output wire [31:0] data_sram_wdata,
    input  wire [31:0] data_sram_rdata,

    output wire [31:0] debug_wb_pc,
    output wire [ 3:0] debug_wb_rf_we,
    output wire [ 4:0] debug_wb_rf_wnum,
    output wire [31:0] debug_wb_rf_wdata,

    output wire        debug_last_wb_valid,
    output wire [31:0] debug_last_wb_pc,
    output wire [ 4:0] debug_last_wb_wnum,
    output wire [31:0] debug_last_wb_wdata,

    output wire        debug_commit_valid,
    output wire [31:0] debug_commit_pc,
    output wire [31:0] debug_commit_inst,
    output wire [31:0] debug_fetch_pc,
    output wire [ 3:0] debug_pipe_valid,
    output wire [ 2:0] debug_pipe_hazard
);

    mycpu_pipeline u_cpu(
        .clk                 (clk),
        .resetn              (resetn),
        .cpu_en              (cpu_en),

        .inst_sram_we        (inst_sram_we),
        .inst_sram_addr      (inst_sram_addr),
        .inst_sram_wdata     (inst_sram_wdata),
        .inst_sram_rdata     (inst_sram_rdata),

        .data_sram_we        (data_sram_we),
        .data_sram_addr      (data_sram_addr),
        .data_sram_wdata     (data_sram_wdata),
        .data_sram_rdata     (data_sram_rdata),

        .debug_wb_pc         (debug_wb_pc),
        .debug_wb_rf_we      (debug_wb_rf_we),
        .debug_wb_rf_wnum    (debug_wb_rf_wnum),
        .debug_wb_rf_wdata   (debug_wb_rf_wdata),

        .debug_last_wb_valid (debug_last_wb_valid),
        .debug_last_wb_pc    (debug_last_wb_pc),
        .debug_last_wb_wnum  (debug_last_wb_wnum),
        .debug_last_wb_wdata (debug_last_wb_wdata),

        .debug_commit_valid  (debug_commit_valid),
        .debug_commit_pc     (debug_commit_pc),
        .debug_commit_inst   (debug_commit_inst),
        .debug_fetch_pc      (debug_fetch_pc),
        .debug_pipe_valid    (debug_pipe_valid),
        .debug_pipe_hazard   (debug_pipe_hazard)
    );

endmodule
