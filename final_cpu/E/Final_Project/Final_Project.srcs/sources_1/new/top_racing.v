module top_racing(
    input wire clk,             // 100MHz 板载时钟
    input wire resetn,          // 复位信号
    input wire input_sel,       // 用作 Start 键 (对应 SW18 / AC21)
    input wire sw_cin,          // 用作 Right 键 (对应 SW25 / Y6)
    // 还需要一个左键，我们可以复用另一个拨码开关或者按键，这里假设复用 input_sel 旁边的开关
    // 为了方便，本例只用两个键演示逻辑：Start和Right。
    // *建议在实际实验中绑定板载按键*
    
    // LCD 物理接口 (对应CSV)
    output wire lcd_rst,
    output wire led_cs, // 片选，部分屏需要
    output wire lcd_bl_ctr,
    output wire lcd_clk,
    output wire lcd_hs,
    output wire lcd_vs,
    output wire lcd_de,
    output wire [15:0] lcd_rgb // 对应 DB1~DB17 (去除空闲位)
);

    // 1. 时钟分频
    reg [24:0] clk_cnt;
    always @(posedge clk) clk_cnt <= clk_cnt + 1;
    
    wire clk_lcd = clk_cnt[1];   // ~25MHz (足够驱动480x272)
    wire tick_en = (clk_cnt == 25'd24_999_999); // 每~0.25秒一个节拍

    // 2. 按键信号处理 (简单映射，建议实验中添加消抖模块)
    wire btn_start = ~input_sel; // 拨码开关拨动
    wire btn_right = ~sw_cin;
    wire btn_left  = 0;          // 暂未绑定，需在XDC添加

    // 3. 实例化核心
    wire [1:0] car_col;
    wire [7:0] obs0, obs1, obs2;
    wire [1:0] state;

    game_core u_core (
        .clk(clk),
        .rst_n(resetn),
        .tick_en(tick_en),
        .btn_left(btn_left),
        .btn_right(btn_right),
        .btn_start(btn_start),
        .car_col(car_col),
        .obs_col0(obs0),
        .obs_col1(obs1),
        .obs_col2(obs2),
        .game_state(state)
    );

    // 4. 实例化LCD驱动
    lcd_driver u_lcd (
        .clk_lcd(clk_lcd),
        .rst_n(resetn),
        .car_col(car_col),
        .obs_col0(obs0),
        .obs_col1(obs1),
        .obs_col2(obs2),
        .game_state(state),
        .lcd_clk(lcd_clk),
        .lcd_hs(lcd_hs),
        .lcd_vs(lcd_vs),
        .lcd_de(lcd_de),
        .lcd_bl(lcd_bl_ctr),
        .lcd_rgb(lcd_rgb)
    );

    // 其他LCD控制信号固定电平
    assign lcd_rst = 1'b1;
    assign led_cs = 1'b1; // 若屏需要片选则置0或1，视手册定，通常常有效即可

endmodule