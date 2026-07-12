module lcd_driver(
    input wire clk_lcd,        // 9MHz 像素时钟
    input wire rst_n,
    input wire [1:0] car_col,  // 赛车位置
    input wire [7:0] obs_col0, // 障碍物数据
    input wire [7:0] obs_col1,
    input wire [7:0] obs_col2,
    input wire [1:0] game_state,
    
    // LCD 硬件接口
    output wire lcd_clk,
    output wire lcd_hs,
    output wire lcd_vs,
    output wire lcd_de,
    output wire lcd_bl,
    output reg [15:0] lcd_rgb // RGB565格式
);

    // 4.3寸屏参数 (480x272)
    parameter H_SYNC = 41, H_BACK = 2, H_DISP = 480, H_FRONT = 2, H_TOTAL = 525;
    parameter V_SYNC = 10, V_BACK = 2, V_DISP = 272, V_FRONT = 2, V_TOTAL = 286;

    reg [9:0] h_cnt;
    reg [9:0] v_cnt;

    // 计数器逻辑
    always @(posedge clk_lcd or negedge rst_n) begin
        if(!rst_n) begin h_cnt <= 0; v_cnt <= 0; end
        else begin
            if(h_cnt == H_TOTAL - 1) begin
                h_cnt <= 0;
                if(v_cnt == V_TOTAL - 1) v_cnt <= 0;
                else v_cnt <= v_cnt + 1;
            end else h_cnt <= h_cnt + 1;
        end
    end

    // 生成同步信号
    assign lcd_clk = clk_lcd;
    assign lcd_hs = (h_cnt < H_SYNC) ? 0 : 1;
    assign lcd_vs = (v_cnt < V_SYNC) ? 0 : 1;
    assign lcd_de = (h_cnt >= H_SYNC + H_BACK) && (h_cnt < H_SYNC + H_BACK + H_DISP) &&
                    (v_cnt >= V_SYNC + V_BACK) && (v_cnt < V_SYNC + V_BACK + V_DISP);
    assign lcd_bl = 1; // 背光常亮

    // 计算当前有效显示区域坐标 (x, y)
    wire [9:0] pix_x = (lcd_de) ? (h_cnt - (H_SYNC + H_BACK)) : 0;
    wire [9:0] pix_y = (lcd_de) ? (v_cnt - (V_SYNC + V_BACK)) : 0;

    // --- 图形绘制逻辑 ---
    // 屏幕分为3列，每列宽 160 (480/3)
    // 屏幕分为8行，每行高 34 (272/8)
    wire [1:0] grid_col = (pix_x < 160) ? 0 : (pix_x < 320) ? 1 : 2;
    wire [2:0] grid_row = pix_y[8:5]; // 简单除以32近似行高，实际272/32=8.5行

    // 判断当前像素是否是障碍物
    wire is_obstacle = (grid_col == 0) ? obs_col0[grid_row] :
                       (grid_col == 1) ? obs_col1[grid_row] : obs_col2[grid_row];

    // 判断当前像素是否是赛车 (赛车固定在第6行)
    wire is_car = (grid_row == 6) && (grid_col == car_col);

    always @(*) begin
        if (!lcd_de) begin
            lcd_rgb = 16'h0000;
        end else begin
            if (game_state == 0) begin // IDLE: 蓝色背景
                lcd_rgb = 16'h001F; 
            end else if (game_state == 2) begin // OVER: 红色背景
                lcd_rgb = 16'hF800;
            end else begin // RUN: 游戏画面
                if (is_car)       lcd_rgb = 16'h07E0; // 绿色赛车
                else if (is_obstacle) lcd_rgb = 16'hF800; // 红色障碍
                else if (pix_x == 159 || pix_x == 319) lcd_rgb = 16'hFFFF; // 白色分割线
                else lcd_rgb = 16'h0000; // 黑色背景
            end
        end
    end
endmodule