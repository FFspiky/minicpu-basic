// 8位共阴极数码管显示 16bit 十进制数
// - 段选 seg_cat[7:0] = {dp,g,f,e,d,c,b,a}，高电平点亮
// - 位选 seg_an[7:0]  对应 CSN0~CSN7，低电平选中该位
// - 从左到右：seg_an[0] -> 最左第1位，seg_an[7] -> 最右第8位
// - 显示顺序：最右第8位 = 个位，向左依次是十位、百位……
// - 不足 8 位的高位用 0 填充

module seg_score_hex(
    input        clk,       // 100MHz
    input        rst_n,
    input [15:0] value,     // 要显示的 16bit 数值（0~65535）

    output reg [7:0] seg_an,   // 位选，低有效
    output reg [7:0] seg_cat   // 段选，高有效: {dp,g,f,e,d,c,b,a}
);

    // -------------------------------------------------
    // 刷新扫描
    // -------------------------------------------------
    reg [15:0] refresh_cnt;
    reg [2:0]  digit_idx;      

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            refresh_cnt <= 16'd0;
            digit_idx   <= 3'd0;
        end else begin
            refresh_cnt <= refresh_cnt + 1'b1;
            if (refresh_cnt == 16'd5000) begin
                refresh_cnt <= 16'd0;
                digit_idx   <= digit_idx + 3'd1;
            end
        end
    end


    // -------------------------------------------------
    // 二进制 → 8 个十进制数字
    // -------------------------------------------------
    reg [3:0] d0, d1, d2, d3, d4, d5, d6, d7;

    integer tmp;   // ← 必须放在 always 外面声明

    always @(*) begin
        tmp = value;

        d0 = tmp % 10; tmp = tmp / 10;
        d1 = tmp % 10; tmp = tmp / 10;
        d2 = tmp % 10; tmp = tmp / 10;
        d3 = tmp % 10; tmp = tmp / 10;
        d4 = tmp % 10; tmp = tmp / 10;
        d5 = tmp % 10; tmp = tmp / 10;
        d6 = tmp % 10; tmp = tmp / 10;
        d7 = tmp % 10;
    end


    // -------------------------------------------------
    // 位选 + 当前数字
    // -------------------------------------------------
    reg [3:0] cur_digit;

    always @(*) begin
        case (digit_idx)
            3'd0: begin seg_an = 8'b0111_1111; cur_digit = d0; end
            3'd1: begin seg_an = 8'b1011_1111; cur_digit = d1; end
            3'd2: begin seg_an = 8'b1101_1111; cur_digit = d2; end
            3'd3: begin seg_an = 8'b1110_1111; cur_digit = d3; end
            3'd4: begin seg_an = 8'b1111_0111; cur_digit = d4; end
            3'd5: begin seg_an = 8'b1111_1011; cur_digit = d5; end
            3'd6: begin seg_an = 8'b1111_1101; cur_digit = d6; end
            3'd7: begin seg_an = 8'b1111_1110; cur_digit = d7; end
            default: begin seg_an = 8'b1111_1111; cur_digit = 4'd0; end
        endcase
    end


    // -------------------------------------------------
    // 段选：十进制数字 → 共阴极编码（高电平点亮）
    // seg_cat[7:0] = {dp,g,f,e,d,c,b,a}
    // -------------------------------------------------
    always @(*) begin
        case (cur_digit)
            4'd0: seg_cat = 8'b0011_1111; 
            4'd1: seg_cat = 8'b0000_0110; 
            4'd2: seg_cat = 8'b0101_1011; 
            4'd3: seg_cat = 8'b0100_1111; 
            4'd4: seg_cat = 8'b0110_0110;
            4'd5: seg_cat = 8'b0110_1101; 
            4'd6: seg_cat = 8'b0111_1101; 
            4'd7: seg_cat = 8'b0000_0111; 
            4'd8: seg_cat = 8'b0111_1111; 
            4'd9: seg_cat = 8'b0110_1111; 
            default: seg_cat = 8'b0000_0000; 
        endcase
    end

endmodule
