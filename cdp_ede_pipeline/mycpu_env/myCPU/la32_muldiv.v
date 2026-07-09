`timescale 1ns / 1ps

module la32_muldiv(
    input  wire [31:0] src1,
    input  wire [31:0] src2,
    input  wire        op_mul_w,
    input  wire        op_mulh_w,
    input  wire        op_mulh_wu,
    input  wire        op_div_w,
    input  wire        op_div_wu,
    input  wire        op_mod_w,
    input  wire        op_mod_wu,
    output reg  [31:0] result
);

    wire signed [31:0] s_src1 = src1;
    wire signed [31:0] s_src2 = src2;
    wire signed [63:0] s_prod = s_src1 * s_src2;
    wire [63:0]        u_prod = src1 * src2;
    wire               div_overflow = src1 == 32'h80000000 && src2 == 32'hffffffff;

    wire [31:0] src1_abs = src1[31] ? (~src1 + 32'd1) : src1;
    wire [31:0] src2_abs = src2[31] ? (~src2 + 32'd1) : src2;
    wire [31:0] abs_quot = (src2_abs == 32'b0) ? 32'b0 : src1_abs / src2_abs;
    wire [31:0] abs_rem  = (src2_abs == 32'b0) ? src1_abs : src1_abs % src2_abs;
    wire [31:0] div_w_result = (src2 == 32'b0) ? 32'b0 :
                                div_overflow ? 32'h80000000 :
                                (src1[31] ^ src2[31]) ? (~abs_quot + 32'd1) : abs_quot;
    wire [31:0] mod_w_result = (src2 == 32'b0) ? src1 :
                                div_overflow ? 32'b0 :
                                src1[31] ? (~abs_rem + 32'd1) : abs_rem;

    always @(*) begin
        result = 32'b0;
        if (op_mul_w) begin
            result = u_prod[31:0];
        end
        else if (op_mulh_w) begin
            result = s_prod[63:32];
        end
        else if (op_mulh_wu) begin
            result = u_prod[63:32];
        end
        else if (op_div_w) begin
            result = div_w_result;
        end
        else if (op_div_wu) begin
            result = (src2 == 32'b0) ? 32'b0 : src1 / src2;
        end
        else if (op_mod_w) begin
            result = mod_w_result;
        end
        else if (op_mod_wu) begin
            result = (src2 == 32'b0) ? src1 : src1 % src2;
        end
    end

endmodule
