`timescale 1ns / 1ps

module ifetch_unit(
    input         clk,
    input         resetn,
    input         cpu_en,
    input  [31:0] next_pc,
    output reg [31:0] pc,
    output [31:0] seq_pc,
    output [31:0] inst
);

    localparam RESET_PC = 32'h1c000000;

    wire [31:0] inst_addr_full;
    wire [15:0] inst_addr;

    assign seq_pc = pc + 32'd4;

    always @(posedge clk) begin
        if (!resetn) begin
            pc <= RESET_PC;
        end
        else if (cpu_en) begin
            pc <= next_pc;
        end
    end

    assign inst_addr_full = (pc - RESET_PC) >> 2;
    assign inst_addr      = inst_addr_full[15:0];

    inst_rom u_inst_rom(
        .a   (inst_addr),
        .spo (inst)
    );

endmodule
