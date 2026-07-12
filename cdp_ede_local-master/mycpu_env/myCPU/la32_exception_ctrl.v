`timescale 1ns / 1ps

// EXP16 exception priority and exception payload selection.  Interrupts are
// sampled at an instruction boundary; synchronous faults then follow the
// priority used by the functional-test reference core.
module la32_exception_ctrl(
    input  wire        interrupt_pending,
    input  wire [31:0] pc,
    input  wire        inst_valid,
    input  wire        inst_syscall,
    input  wire        inst_break,
    input  wire        mem_access,
    input  wire        mem_align_error,
    input  wire [31:0] mem_addr,
    output reg         exception_valid,
    output reg  [ 5:0] exception_ecode,
    output reg  [31:0] exception_badv
);
    localparam ECODE_INT = 6'h00;
    localparam ECODE_ADE = 6'h08;
    localparam ECODE_ALE = 6'h09;
    localparam ECODE_SYS = 6'h0b;
    localparam ECODE_BRK = 6'h0c;
    localparam ECODE_INE = 6'h0d;

    always @(*) begin
        exception_valid = 1'b0;
        exception_ecode = ECODE_INE;
        exception_badv  = 32'b0;

        if (interrupt_pending) begin
            exception_valid = 1'b1;
            exception_ecode = ECODE_INT;
        end else if (pc[1:0] != 2'b00) begin
            exception_valid = 1'b1;
            exception_ecode = ECODE_ADE;
            exception_badv  = pc;
        end else if (!inst_valid) begin
            exception_valid = 1'b1;
            exception_ecode = ECODE_INE;
        end else if (inst_syscall) begin
            exception_valid = 1'b1;
            exception_ecode = ECODE_SYS;
        end else if (inst_break) begin
            exception_valid = 1'b1;
            exception_ecode = ECODE_BRK;
        end else if (mem_access && mem_align_error) begin
            exception_valid = 1'b1;
            exception_ecode = ECODE_ALE;
            exception_badv  = mem_addr;
        end
    end
endmodule
