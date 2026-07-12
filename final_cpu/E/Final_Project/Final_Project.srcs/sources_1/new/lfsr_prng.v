// 16bit LFSR 伪随机数，输出 2bit 车道编号
module lfsr_prng(
    input clk,
    input rst_n,
    output reg [1:0] random_lane
);
    reg [15:0] lfsr_reg;
    // 多项式: x^16 + x^14 + x^13 + x^11 + 1
    wire feedback = lfsr_reg[15] ^ lfsr_reg[13] ^ lfsr_reg[12] ^ lfsr_reg[10];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            lfsr_reg    <= 16'hACE1; // 初始种子
            random_lane <= 2'b00;
        end else begin
            lfsr_reg    <= {lfsr_reg[14:0], feedback};
            random_lane <= lfsr_reg[1:0]; 
        end
    end
endmodule
