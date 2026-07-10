`timescale 1ns / 1ps

module branch_unit(
    input         br_en,
    input  [2:0]  br_op,
    input         sel_nextpc,
    input         jirl_sel,
    input  [31:0] pc,
    input  [31:0] seq_pc,
    input  [31:0] branch_offs,
    input  [31:0] rdata1,
    input  [31:0] rdata2,
    output [31:0] next_pc,
    output        br_taken
);

    localparam BR_EQ  = 3'b000;
    localparam BR_NE  = 3'b001;
    localparam BR_LT  = 3'b010;
    localparam BR_GE  = 3'b011;
    localparam BR_LTU = 3'b100;
    localparam BR_GEU = 3'b101;

    reg cond_taken;

    wire [31:0] branch_base;
    wire [31:0] branch_target;

    always @(*) begin
        case (br_op)
            BR_EQ : cond_taken = rdata1 == rdata2;
            BR_NE : cond_taken = rdata1 != rdata2;
            BR_LT : cond_taken = $signed(rdata1) <  $signed(rdata2);
            BR_GE : cond_taken = $signed(rdata1) >= $signed(rdata2);
            BR_LTU: cond_taken = rdata1 <  rdata2;
            BR_GEU: cond_taken = rdata1 >= rdata2;
            default: cond_taken = 1'b0;
        endcase
    end

    assign br_taken   = br_en & (sel_nextpc ? cond_taken : 1'b1);

    assign branch_base   = jirl_sel ? pc : rdata1;
    assign branch_target = branch_base + branch_offs;

    assign next_pc = br_taken ? branch_target : seq_pc;

endmodule
