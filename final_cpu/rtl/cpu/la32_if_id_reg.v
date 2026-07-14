`timescale 1ns / 1ps

module la32_if_id_reg(
    input wire clk, input wire resetn, input wire cpu_en,
    input wire flush, input wire hold, input wire bubble,
    input wire in_valid, input wire [31:0] in_pc,
    input wire [31:0] in_pc_plus4, input wire [31:0] in_inst,
    input wire in_exc_valid, input wire [5:0] in_ecode,
    input wire [8:0] in_esubcode, input wire [31:0] in_badv,
    output reg out_valid, output reg [31:0] out_pc,
    output reg [31:0] out_pc_plus4, output reg [31:0] out_inst,
    output reg out_exc_valid, output reg [5:0] out_ecode,
    output reg [8:0] out_esubcode, output reg [31:0] out_badv
);
    always @(posedge clk) begin
        if (!resetn) begin
            out_valid <= 1'b0; out_pc <= 0; out_pc_plus4 <= 0; out_inst <= 0;
            out_exc_valid <= 0; out_ecode <= 0; out_esubcode <= 0; out_badv <= 0;
        end else if (cpu_en) begin
            if (flush) out_valid <= 1'b0;
            else if (hold) out_valid <= out_valid;
            else if (bubble) out_valid <= 1'b0;
            else begin
                out_valid <= in_valid; out_pc <= in_pc; out_pc_plus4 <= in_pc_plus4;
                out_inst <= in_inst; out_exc_valid <= in_exc_valid;
                out_ecode <= in_ecode; out_esubcode <= in_esubcode; out_badv <= in_badv;
            end
        end
    end
endmodule
