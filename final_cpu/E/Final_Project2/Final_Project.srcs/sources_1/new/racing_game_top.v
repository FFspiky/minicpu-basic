module racing_game_top(
    input  wire        clk,        // 100MHz
    input  wire        rst_n,

    // Matrix Keypad
    output wire [3:0]  key_col,
    input  wire [3:0]  key_row,

    // LCD Interface (NT35510, 16bit 8080)
    output wire [15:0] lcd_db,
    output wire        lcd_wr,
    output wire        lcd_rs,     // 0:Command, 1:Data
    output wire        lcd_cs,
    output wire        lcd_rd,
    output wire        lcd_rst,
    output wire        lcd_bl_ctr,

    // LEDs
    output wire [15:0] leds,

    // 8位数码管
    output wire [7:0]  seg_an,
    output wire [7:0]  seg_cat
);

    // =========================================================
    // 1) 心跳 & LED 状态
    // =========================================================
    reg [26:0] heartbeat;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) heartbeat <= 27'd0;
        else        heartbeat <= heartbeat + 1'b1;
    end
    assign leds[0] = heartbeat[26]; // LED0 闪烁表示 FPGA 活着

    // =========================================================
    // 2) 60Hz 游戏节拍
    // =========================================================
    reg [20:0] tick_cnt;
    wire tick_60hz = (tick_cnt == 21'd1_666_666);
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) tick_cnt <= 0;
        else if(tick_60hz)  tick_cnt <= 0;
        else                tick_cnt <= tick_cnt + 1'b1;
    end

    // =========================================================
    // 3) 随机数
    // =========================================================
    wire [1:0] rand_lane;
    lfsr_prng u_prng(
        .clk        (clk),
        .rst_n      (rst_n),
        .random_lane(rand_lane)
    );

    // =========================================================
    // 4) 按键扫描
    // =========================================================
    wire in_L, in_R, in_U, in_D;
    wire [3:0] col_w;
    matrix_keypad_scanner u_key(
        .clk      (clk),
        .rst_n    (rst_n),
        .row_in   (key_row),
        .col_out  (col_w),
        .cmd_left (in_L),
        .cmd_right(in_R),
        .cmd_up   (in_U),
        .cmd_down (in_D)
    );
    assign key_col = col_w;

    // =========================================================
    // 5) 游戏核心
    // =========================================================
    wire [1:0]  car_lane, obs_lane, bonus_lane;
    wire [9:0]  obs_x, bonus_x;
    wire        bonus_active;
    wire        game_over;
    wire        paused;
    wire [15:0] score;

    wire any_key = in_L | in_R | in_U | in_D; // 任意键开始

    game_core1 u_game(
        .clk         (clk),
        .rst_n       (rst_n),
        .tick_60hz   (tick_60hz),
        .in_left     (in_L),
        .in_right    (in_R),
        .in_accel    (in_U),
        .in_pause    (in_D),
        .in_start    (any_key),
        .rand_in     (rand_lane),
        .car_lane    (car_lane),
        .obs_pos_x   (obs_x),
        .obs_lane    (obs_lane),
        .bonus_pos_x (bonus_x),
        .bonus_lane  (bonus_lane),
        .bonus_active(bonus_active),
        .game_over   (game_over),
        .score       (score),
        .paused      (paused)
    );

    // 车道调试灯（低电平亮）
    assign leds[1] = ~(car_lane == 0);
    assign leds[2] = ~(car_lane == 1);
    assign leds[3] = ~(car_lane == 2);

    // =========================================================
    // 6) 数码管显示分数
    // =========================================================
    seg_score_hex u_seg(
        .clk    (clk),
        .rst_n  (rst_n),
        .value  (score),
        .seg_an (seg_an),
        .seg_cat(seg_cat)
    );

    // =========================================================
    // 7) LCD 驱动模块（已分离）
    // =========================================================
    wire [3:0] lcd_status;

    lcd_nt35510_driver u_lcd(
        .clk         (clk),
        .rst_n       (rst_n),

        .lcd_db      (lcd_db),
        .lcd_wr      (lcd_wr),
        .lcd_rs      (lcd_rs),
        .lcd_cs      (lcd_cs),
        .lcd_rd      (lcd_rd),
        .lcd_rst     (lcd_rst),
        .lcd_bl_ctr  (lcd_bl_ctr),

        .status      (lcd_status),

        .car_lane    (car_lane),
        .obs_lane    (obs_lane),
        .obs_x       (obs_x),
        .bonus_lane  (bonus_lane),
        .bonus_x     (bonus_x),
        .bonus_active(bonus_active),
        .game_over   (game_over),
        .paused      (paused)
    );

    // LCD 状态码显示到 LED7~4（低电平亮）
    assign leds[7:4]  = ~lcd_status;
    assign leds[15:8] = 8'hFF;

endmodule
