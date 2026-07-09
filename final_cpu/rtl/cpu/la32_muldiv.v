`timescale 1ns / 1ps

module la32_muldiv(
    input  wire        clk,
    input  wire        resetn,
    input  wire        cpu_en,
    input  wire        start,
    input  wire        clear,
    input  wire        kill,
    input  wire [31:0] src1,
    input  wire [31:0] src2,
    input  wire        op_mul_w,
    input  wire        op_mulh_w,
    input  wire        op_mulh_wu,
    input  wire        op_div_w,
    input  wire        op_div_wu,
    input  wire        op_mod_w,
    input  wire        op_mod_wu,
    output wire        busy,
    output reg         done,
    output reg  [31:0] result
);

    localparam ST_IDLE = 2'd0;
    localparam ST_MUL  = 2'd1;
    localparam ST_DIV  = 2'd2;
    localparam ST_DONE = 2'd3;

    reg [1:0] state;

    reg [31:0] mul_a;
    reg [31:0] mul_b;
    reg        mul_op_low;
    reg        mul_op_signed_hi;

    reg        div_is_mod;
    reg        div_neg_quot;
    reg        div_neg_rem;
    reg [31:0] div_dividend;
    reg [31:0] div_divisor;
    reg [31:0] div_quot;
    reg [32:0] div_rem;
    reg [ 5:0] div_cnt;

    wire start_mul = start & (op_mul_w | op_mulh_w | op_mulh_wu);
    wire start_div = start & (op_div_w | op_div_wu | op_mod_w | op_mod_wu);
    wire signed_div = op_div_w | op_mod_w;
    wire start_mod = op_mod_w | op_mod_wu;
    wire div_by_zero = src2 == 32'b0;
    wire div_overflow = signed_div & (src1 == 32'h80000000) & (src2 == 32'hffffffff);

    wire [31:0] src1_abs = (signed_div & src1[31]) ? (~src1 + 32'd1) : src1;
    wire [31:0] src2_abs = (signed_div & src2[31]) ? (~src2 + 32'd1) : src2;

    wire signed [31:0] mul_a_signed = mul_a;
    wire signed [31:0] mul_b_signed = mul_b;
    wire signed [63:0] signed_product = mul_a_signed * mul_b_signed;
    wire [63:0] unsigned_product = mul_a * mul_b;

    wire [32:0] div_trial_rem = {div_rem[31:0], div_dividend[31]};
    wire        div_trial_ge = div_trial_rem >= {1'b0, div_divisor};
    wire [32:0] div_rem_next = div_trial_ge ? (div_trial_rem - {1'b0, div_divisor}) :
                                               div_trial_rem;
    wire [31:0] div_quot_next = {div_quot[30:0], div_trial_ge};
    wire [31:0] div_dividend_next = {div_dividend[30:0], 1'b0};
    wire [31:0] div_signed_quot = div_neg_quot ? (~div_quot_next + 32'd1) : div_quot_next;
    wire [31:0] div_signed_rem = div_neg_rem ? (~div_rem_next[31:0] + 32'd1) :
                                               div_rem_next[31:0];

    assign busy = state == ST_MUL || state == ST_DIV;

    always @(posedge clk) begin
        if (!resetn || kill) begin
            state        <= ST_IDLE;
            done         <= 1'b0;
            result       <= 32'b0;
            mul_a        <= 32'b0;
            mul_b        <= 32'b0;
            mul_op_low   <= 1'b0;
            mul_op_signed_hi <= 1'b0;
            div_is_mod   <= 1'b0;
            div_neg_quot <= 1'b0;
            div_neg_rem  <= 1'b0;
            div_dividend <= 32'b0;
            div_divisor  <= 32'b0;
            div_quot     <= 32'b0;
            div_rem      <= 33'b0;
            div_cnt      <= 6'b0;
        end
        else if (cpu_en) begin
            if (clear) begin
                state <= ST_IDLE;
                done  <= 1'b0;
            end
            else begin
                case (state)
                    ST_IDLE: begin
                        done <= 1'b0;
                        if (start_mul) begin
                            state            <= ST_MUL;
                            mul_a            <= src1;
                            mul_b            <= src2;
                            mul_op_low       <= op_mul_w;
                            mul_op_signed_hi <= op_mulh_w;
                        end
                        else if (start_div) begin
                            if (div_by_zero) begin
                                state  <= ST_DONE;
                                done   <= 1'b1;
                                result <= start_mod ? src1 : 32'b0;
                            end
                            else if (div_overflow) begin
                                state  <= ST_DONE;
                                done   <= 1'b1;
                                result <= start_mod ? 32'b0 : 32'h80000000;
                            end
                            else begin
                                state        <= ST_DIV;
                                div_is_mod   <= start_mod;
                                div_neg_quot <= signed_div & (src1[31] ^ src2[31]);
                                div_neg_rem  <= signed_div & src1[31];
                                div_dividend <= src1_abs;
                                div_divisor  <= src2_abs;
                                div_quot     <= 32'b0;
                                div_rem      <= 33'b0;
                                div_cnt      <= 6'b0;
                            end
                        end
                    end

                    ST_MUL: begin
                        state <= ST_DONE;
                        done  <= 1'b1;
                        if (mul_op_low) begin
                            result <= unsigned_product[31:0];
                        end
                        else if (mul_op_signed_hi) begin
                            result <= signed_product[63:32];
                        end
                        else begin
                            result <= unsigned_product[63:32];
                        end
                    end

                    ST_DIV: begin
                        div_rem      <= div_rem_next;
                        div_quot     <= div_quot_next;
                        div_dividend <= div_dividend_next;
                        if (div_cnt == 6'd31) begin
                            state  <= ST_DONE;
                            done   <= 1'b1;
                            result <= div_is_mod ? div_signed_rem : div_signed_quot;
                        end
                        else begin
                            div_cnt <= div_cnt + 6'd1;
                        end
                    end

                    default: begin
                        done <= 1'b1;
                    end
                endcase
            end
        end
    end

endmodule
