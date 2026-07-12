`timescale 1ns / 1ps

module la32_exception_control(
    input  wire        ws_valid,
    input  wire        ws_exception,
    input  wire        ws_tlbr,
    input  wire        ws_ertn,
    input  wire        ws_flush_after,
    input  wire [31:0] ws_pc,
    input  wire [31:0] csr_eentry,
    input  wire [31:0] csr_tlbrentry,
    input  wire [31:0] csr_era,
    input  wire        pipe_empty,
    input  wire        has_interrupt,
    output wire        exception_commit,
    output wire        ertn_commit,
    output wire        redirect,
    output wire [31:0] redirect_pc,
    output wire        fetch_interrupt
);

    assign exception_commit = ws_valid & ws_exception;
    assign ertn_commit = ws_valid & !ws_exception & ws_ertn;
    assign redirect = ws_valid & (ws_exception | ws_ertn | ws_flush_after);
    assign redirect_pc = ws_exception ? (ws_tlbr ? csr_tlbrentry : csr_eentry) :
                         ws_ertn ? csr_era : (ws_pc + 32'd4);
    assign fetch_interrupt = pipe_empty & has_interrupt;

endmodule
