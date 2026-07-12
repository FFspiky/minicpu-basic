`timescale 1ns / 1ps

module la32_fetch_unit(
    input  wire        clk,
    input  wire        resetn,
    input  wire        cpu_en,
    input  wire        wb_redirect,
    input  wire [31:0] wb_redirect_pc,
    input  wire        ex_redirect,
    input  wire [31:0] ex_redirect_pc,
    input  wire        fetch_fire,
    input  wire        fetch_exception,
    input  wire        fetch_interrupt,
    input  wire [ 5:0] trans_ecode,
    input  wire [ 8:0] trans_esubcode,
    input  wire        trans_tlbr,
    input  wire        fs_allowin,
    input  wire [31:0] inst_rdata,
    output reg  [31:0] pc,
    output reg         pending,
    output reg         fs_valid,
    output reg  [31:0] fs_pc,
    output reg  [31:0] fs_inst,
    output reg         fs_exc,
    output reg  [ 5:0] fs_ecode,
    output reg  [ 8:0] fs_esubcode,
    output reg  [31:0] fs_badv,
    output reg         fs_tlbr
);

    localparam ECODE_INT = 6'h00;

    reg [31:0] pending_pc;
    reg        pending_exc;
    reg [ 5:0] pending_ecode;
    reg [ 8:0] pending_esubcode;
    reg [31:0] pending_badv;
    reg        pending_tlbr;
    reg        pending_from_mem;

    always @(posedge clk) begin
        if (!resetn) begin
            pc                  <= 32'h1c000000;
            pending             <= 1'b0;
            pending_pc          <= 32'b0;
            pending_exc         <= 1'b0;
            pending_ecode       <= 6'b0;
            pending_esubcode    <= 9'b0;
            pending_badv        <= 32'b0;
            pending_tlbr        <= 1'b0;
            pending_from_mem    <= 1'b0;
            fs_valid            <= 1'b0;
            fs_pc               <= 32'b0;
            fs_inst             <= 32'b0;
            fs_exc              <= 1'b0;
            fs_ecode            <= 6'b0;
            fs_esubcode         <= 9'b0;
            fs_badv             <= 32'b0;
            fs_tlbr             <= 1'b0;
        end
        else if (cpu_en) begin
            if (wb_redirect) begin
                pc <= wb_redirect_pc;
            end
            else if (ex_redirect) begin
                pc <= ex_redirect_pc;
            end
            else if (fetch_fire) begin
                pc <= pc + 32'd4;
            end

            if (wb_redirect | ex_redirect) begin
                pending <= 1'b0;
            end
            else begin
                pending <= fetch_fire;
                if (fetch_fire) begin
                    pending_pc       <= pc;
                    pending_exc      <= fetch_exception;
                    pending_ecode    <= fetch_interrupt ? ECODE_INT : trans_ecode;
                    pending_esubcode <= fetch_interrupt ? 9'b0 : trans_esubcode;
                    pending_badv     <= fetch_interrupt ? 32'b0 : pc;
                    pending_tlbr     <= fetch_interrupt ? 1'b0 : trans_tlbr;
                    pending_from_mem <= !fetch_exception;
                end
            end

            if (wb_redirect | ex_redirect) begin
                fs_valid <= 1'b0;
            end
            else if (fs_allowin) begin
                fs_valid    <= pending;
                fs_pc       <= pending_pc;
                fs_inst     <= pending_from_mem ? inst_rdata : 32'b0;
                fs_exc      <= pending_exc;
                fs_ecode    <= pending_ecode;
                fs_esubcode <= pending_esubcode;
                fs_badv     <= pending_badv;
                fs_tlbr     <= pending_tlbr;
            end
        end
    end

endmodule
