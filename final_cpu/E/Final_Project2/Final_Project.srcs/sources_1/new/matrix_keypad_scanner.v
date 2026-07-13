// 4x4 矩阵键盘扫描：适配 SW11/14/15/16 为 上/左/下/右
module matrix_keypad_scanner(
    input clk,
    input rst_n,
    input  [3:0] row_in,
    output reg [3:0] col_out,
    output reg cmd_left,   // SW14
    output reg cmd_right,  // SW16
    output reg cmd_up,     // SW11
    output reg cmd_down    // SW15
);
    reg [19:0] scan_timer;
    reg [1:0]  col_index;

    wire tick = (scan_timer == 20'd100_000); // 1ms @100MHz

    // 1ms 扫描节拍
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) scan_timer <= 20'd0;
        else if (tick) scan_timer <= 20'd0;
        else scan_timer <= scan_timer + 1'b1;
    end

    // 列扫描（低有效）
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            col_index <= 2'd0;
            col_out   <= 4'b1110;
        end else if (tick) begin
            col_index <= col_index + 1'b1;
            case (col_index)
                2'd0: col_out <= 4'b1110;
                2'd1: col_out <= 4'b1101;
                2'd2: col_out <= 4'b1011;
                2'd3: col_out <= 4'b0111;
            endcase
        end
    end

    // 每 1ms 采样一次按键状态（简单去抖）
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cmd_left  <= 1'b0;
            cmd_right <= 1'b0;
            cmd_up    <= 1'b0;
            cmd_down  <= 1'b0;
        end else if (tick) begin
            // 根据板卡丝印上的物理位置映射
            cmd_up    <= (col_out[2] == 1'b0 && row_in[2] == 1'b0); // Col3, Row3 -> SW11
            cmd_left  <= (col_out[1] == 1'b0 && row_in[3] == 1'b0); // Col2, Row4 -> SW14
            cmd_down  <= (col_out[2] == 1'b0 && row_in[3] == 1'b0); // Col3, Row4 -> SW15
            cmd_right <= (col_out[3] == 1'b0 && row_in[3] == 1'b0); // Col4, Row4 -> SW16
        end
    end
endmodule
