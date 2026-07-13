`timescale 1ns / 1ps

module la32_pc(
    input  wire        clk,
    input  wire        resetn,
    input  wire        cpu_en,
    input  wire        fetch_issue_fire,
    input  wire        exception_enter,
    input  wire [31:0] eentry,
    input  wire        ertn_taken,
    input  wire [31:0] era,
    input  wire        branch_redirect_pulse,
    input  wire [31:0] branch_target,
    output wire [ 1:0] redirect_sel,
    output wire        redirect_valid,
    output wire [31:0] redirect_target,
    output wire [31:0] next_pc,
    output reg  [31:0] pc,
    output wire [31:0] pc_plus4,
    output wire        pc_en
);
    assign pc_plus4 = pc + 32'd4;
    assign redirect_valid = exception_enter | ertn_taken |
                            branch_redirect_pulse;
    assign redirect_sel = exception_enter ? 2'b10 :
                          ertn_taken ? 2'b11 :
                          branch_redirect_pulse ? 2'b01 : 2'b00;
    assign redirect_target = exception_enter ? eentry :
                             ertn_taken ? era : branch_target;
    assign next_pc = redirect_valid ? redirect_target : pc_plus4;
    assign pc_en = cpu_en & (redirect_valid | fetch_issue_fire);

    always @(posedge clk) begin
        if (!resetn)
            pc <= 32'h1c000000;
        else if (pc_en)
            pc <= next_pc;
    end
endmodule
