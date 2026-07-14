`timescale 1ns / 1ps
`include "la32_defs.vh"

module la32_exception_control(
    input wire clk, input wire resetn, input wire cpu_en,
    input wire mem_wb_valid, input wire mem_wb_exc_valid,
    input wire mem_wb_ertn, input wire [31:0] mem_wb_pc,
    input wire [5:0] mem_wb_ecode, input wire [8:0] mem_wb_esubcode,
    input wire [31:0] mem_wb_badv,
    input wire pipe_empty, input wire has_interrupt,
    input wire [31:0] fetch_resume_pc,
    input wire branch_redirect_pulse, input wire [31:0] branch_target,
    output wire sync_exception_enter, output wire interrupt_enter,
    output wire exception_enter, output wire ertn_taken,
    output wire interrupt_block_fetch, output wire [31:0] exception_pc,
    output wire [5:0] exception_ecode, output wire [8:0] exception_esubcode,
    output wire [31:0] exception_badv
);
    reg interrupt_pending;
    reg [31:0] interrupt_resume_pc;

    assign sync_exception_enter = cpu_en && mem_wb_valid && mem_wb_exc_valid;
    assign ertn_taken = cpu_en && mem_wb_valid && mem_wb_ertn && !mem_wb_exc_valid;
    assign interrupt_enter = cpu_en && interrupt_pending && pipe_empty &&
                             !sync_exception_enter && !ertn_taken;
    assign exception_enter = sync_exception_enter || interrupt_enter;
    assign interrupt_block_fetch = interrupt_pending ||
                                   (has_interrupt && !sync_exception_enter &&
                                    !ertn_taken);
    assign exception_pc = sync_exception_enter ? mem_wb_pc : interrupt_resume_pc;
    assign exception_ecode = sync_exception_enter ? mem_wb_ecode : `ECODE_INT;
    assign exception_esubcode = sync_exception_enter ? mem_wb_esubcode : 9'b0;
    assign exception_badv = sync_exception_enter ? mem_wb_badv : 32'b0;

    always @(posedge clk) begin
        if (!resetn) begin
            interrupt_pending <= 1'b0;
            interrupt_resume_pc <= 32'b0;
        end else if (cpu_en) begin
            if (sync_exception_enter || ertn_taken || interrupt_enter) begin
                interrupt_pending <= 1'b0;
            end else if (interrupt_pending && branch_redirect_pulse) begin
                interrupt_resume_pc <= branch_target;
            end else if (has_interrupt && !interrupt_pending) begin
                interrupt_pending <= 1'b1;
                interrupt_resume_pc <= branch_redirect_pulse ? branch_target :
                                       fetch_resume_pc;
            end
        end
    end
endmodule
