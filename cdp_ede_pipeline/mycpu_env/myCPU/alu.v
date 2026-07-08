`timescale 1ns / 1ps

module alu(
    input  [31:0] alu_src1,
    input  [31:0] alu_src2,
    input  [3:0]  alu_op,
    output reg [31:0] alu_result
);

    wire op_sub;
    wire op_slt;
    wire op_sltu;

    localparam ALU_ADD  = 4'b0000;
    localparam ALU_SUB  = 4'b0001;
    localparam ALU_SLT  = 4'b0010;
    localparam ALU_SLTU = 4'b0011;
    localparam ALU_SLL  = 4'b0100;
    localparam ALU_SRL  = 4'b0101;
    localparam ALU_SRA  = 4'b0110;
    localparam ALU_AND  = 4'b0111;
    localparam ALU_NOR  = 4'b1000;
    localparam ALU_OR   = 4'b1001;
    localparam ALU_XOR  = 4'b1010;

    assign op_sub  = (alu_op == ALU_SUB);
    assign op_slt  = (alu_op == ALU_SLT);
    assign op_sltu = (alu_op == ALU_SLTU);

    // sub, slt, and sltu all use src1 - src2.
    wire adder_sub;
    assign adder_sub = op_sub | op_slt | op_sltu;

    // Two's complement subtraction: A - B = A + ~B + 1.
    wire [31:0] adder_b;
    assign adder_b = alu_src2 ^ {32{adder_sub}};

    wire [31:0] adder_result;
    wire        adder_cout;

    // 32-bit carry lookahead adder.
    cla32 u_cla32(
        .a    (alu_src1),
        .b    (adder_b),
        .cin  (adder_sub),
        .sum  (adder_result),
        .cout (adder_cout)
    );

    // Signed less-than comparison.
    wire slt_result;
    assign slt_result =
        (alu_src1[31] & ~alu_src2[31]) |
        ((alu_src1[31] == alu_src2[31]) & adder_result[31]);

    // Unsigned less-than comparison. cout=0 means a borrow occurred.
    wire sltu_result;
    assign sltu_result = ~adder_cout;

    wire [31:0] add_sub_result;
    wire [31:0] slt_result_32;
    wire [31:0] sltu_result_32;
    wire [31:0] and_result;
    wire [31:0] nor_result;
    wire [31:0] or_result;
    wire [31:0] xor_result;
    wire [31:0] sll_result;
    wire [31:0] srl_result;
    wire [31:0] sra_result;

    assign add_sub_result = adder_result;
    assign slt_result_32  = {31'b0, slt_result};
    assign sltu_result_32 = {31'b0, sltu_result};
    assign and_result     = alu_src1 & alu_src2;
    assign nor_result     = ~(alu_src1 | alu_src2);
    assign or_result      = alu_src1 | alu_src2;
    assign xor_result     = alu_src1 ^ alu_src2;

    // 32-bit shifts only use the low 5 bits as the shift amount.
    assign sll_result = alu_src1 << alu_src2[4:0];
    assign srl_result = alu_src1 >> alu_src2[4:0];
    assign sra_result = $signed(alu_src1) >>> alu_src2[4:0];

    always @(*) begin
        case (alu_op)
            ALU_ADD : alu_result = add_sub_result;
            ALU_SUB : alu_result = add_sub_result;
            ALU_SLT : alu_result = slt_result_32;
            ALU_SLTU: alu_result = sltu_result_32;
            ALU_SLL : alu_result = sll_result;
            ALU_SRL : alu_result = srl_result;
            ALU_SRA : alu_result = sra_result;
            ALU_AND : alu_result = and_result;
            ALU_NOR : alu_result = nor_result;
            ALU_OR  : alu_result = or_result;
            ALU_XOR : alu_result = xor_result;
            default : alu_result = 32'b0;
        endcase
    end

endmodule
