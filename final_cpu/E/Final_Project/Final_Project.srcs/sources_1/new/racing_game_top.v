module racing_game_top(
    input  wire        clk,        // 100MHz
    input  wire        rst_n,
    // Matrix Keypad
    output wire [3:0]  key_col,
    input  wire [3:0]  key_row,
    // LCD Interface (NT35510, 16bit 8080)
    output reg  [15:0] lcd_db,
    output reg         lcd_wr,
    output reg         lcd_rs,     // 0:Command (Index), 1:Data (Parameter)
    output wire        lcd_cs,
    output wire        lcd_rd,
    output reg         lcd_rst,
    output wire        lcd_bl_ctr,
    // LEDs
    output wire [15:0] leds,
    // 8位数码管
    output wire [7:0]  seg_an,
    output wire [7:0]  seg_cat
);

    // =========================================================
    // 1. 基础信号与心跳
    // =========================================================
    assign lcd_cs     = 1'b0;  // 片选常有效
    assign lcd_rd     = 1'b1;  // 不读
    assign lcd_bl_ctr = 1'b1;  // 背光常亮

    reg [26:0] heartbeat;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) heartbeat <= 27'd0;
        else        heartbeat <= heartbeat + 1'b1;
    end
    assign leds[0] = heartbeat[26]; // LED0 闪烁表示 FPGA 活着

    // LCD 状态码 (LED7~4 显示，低电平亮)
    reg [3:0] status;
    assign leds[7:4]  = ~status;
    assign leds[15:8] = 8'hFF;

    // =========================================================
    // 2. 游戏逻辑模块实例化
    // =========================================================
    
    // 60Hz 游戏节拍
    reg [20:0] tick_cnt;
    wire tick_60hz = (tick_cnt == 21'd1_666_666);
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) tick_cnt <= 0;
        else if(tick_60hz)  tick_cnt <= 0;
        else                tick_cnt <= tick_cnt + 1'b1;
    end

    // 随机数
    wire [1:0] rand_lane;
    lfsr_prng u_prng(
        .clk        (clk),
        .rst_n      (rst_n),
        .random_lane(rand_lane)
    );

    // 按键扫描
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

    // 游戏核心 (横版逻辑 + 奖励 + 计分 + 加速 + 暂停)
    wire [1:0]  car_lane, obs_lane, bonus_lane;
    wire [9:0]  obs_x, bonus_x;
    wire        bonus_active;
    wire        game_over;
    wire        paused;
    wire [15:0] score;
    wire        any_key = in_L | in_R | in_U | in_D; // 任意键开始

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

    // LED显示车道状态 (调试用，低电平亮)
    assign leds[1] = ~(car_lane == 0);
    assign leds[2] = ~(car_lane == 1);
    assign leds[3] = ~(car_lane == 2);

    // 数码管显示分数（你自己的 8 位十进制模块）
    seg_score_hex u_seg(
        .clk    (clk),
        .rst_n  (rst_n),
        .value  (score),
        .seg_an (seg_an),
        .seg_cat(seg_cat)
    );

    // =========================================================
    // 3. LCD 初始化命令表 (NT35510 16-bit, 横屏 800x480)
    // =========================================================
    localparam [16:0] CMD_END = 17'h1_FFFF;
    reg [16:0] cmds [0:128];

    initial begin
        // --- Page 0 解锁 ---
        cmds[0]  = {1'b0, 16'hF000}; cmds[1]  = {1'b1, 16'h0055};
        cmds[2]  = {1'b0, 16'hF001}; cmds[3]  = {1'b1, 16'h00AA};
        cmds[4]  = {1'b0, 16'hF002}; cmds[5]  = {1'b1, 16'h0052};
        cmds[6]  = {1'b0, 16'hF003}; cmds[7]  = {1'b1, 16'h0008};
        cmds[8]  = {1'b0, 16'hF004}; cmds[9]  = {1'b1, 16'h0001};

        // --- Page 1 解锁 ---
        cmds[10] = {1'b0, 16'hF000}; cmds[11] = {1'b1, 16'h0055};
        cmds[12] = {1'b0, 16'hF001}; cmds[13] = {1'b1, 16'h00AA};
        cmds[14] = {1'b0, 16'hF002}; cmds[15] = {1'b1, 16'h0052};
        cmds[16] = {1'b0, 16'hF003}; cmds[17] = {1'b1, 16'h0008};
        cmds[18] = {1'b0, 16'hF004}; cmds[19] = {1'b1, 16'h0001};

        // --- 电源配置 (简化) ---
        cmds[20] = {1'b0, 16'hB000}; cmds[21] = {1'b1, 16'h0000};
        cmds[22] = {1'b0, 16'hB001}; cmds[23] = {1'b1, 16'h0000};
        cmds[24] = {1'b0, 16'hB002}; cmds[25] = {1'b1, 16'h0000};
        
        cmds[26] = {1'b0, 16'hB600}; cmds[27] = {1'b1, 16'h0024};
        cmds[28] = {1'b0, 16'hB601}; cmds[29] = {1'b1, 16'h0024};
        cmds[30] = {1'b0, 16'hB602}; cmds[31] = {1'b1, 16'h0024};

        cmds[32] = {1'b0, 16'hB700}; cmds[33] = {1'b1, 16'h0024};
        cmds[34] = {1'b0, 16'hB701}; cmds[35] = {1'b1, 16'h0024};
        cmds[36] = {1'b0, 16'hB702}; cmds[37] = {1'b1, 16'h0024};

        // --- Sleep Out ---
        cmds[38] = {1'b0, 16'h1100}; 
        cmds[39] = {1'b1, 16'h0000}; // 占位符 -> Sleep Out 后延时

        // --- Memory Access Control (横屏方向) ---
        cmds[40] = {1'b0, 16'h3600}; cmds[41] = {1'b1, 16'h00A0};

        // --- Pixel Format (RGB565) ---
        cmds[42] = {1'b0, 16'h3A00}; cmds[43] = {1'b1, 16'h0055};

        // --- Column Address Set (X: 0~799) ---
        cmds[44] = {1'b0, 16'h2A00}; cmds[45] = {1'b1, 16'h0000};
        cmds[46] = {1'b0, 16'h2A01}; cmds[47] = {1'b1, 16'h0000};
        cmds[48] = {1'b0, 16'h2A02}; cmds[49] = {1'b1, 16'h0003};
        cmds[50] = {1'b0, 16'h2A03}; cmds[51] = {1'b1, 16'h001F}; // 799

        // --- Page Address Set (Y: 0~479) ---
        cmds[52] = {1'b0, 16'h2B00}; cmds[53] = {1'b1, 16'h0000};
        cmds[54] = {1'b0, 16'h2B01}; cmds[55] = {1'b1, 16'h0000};
        cmds[56] = {1'b0, 16'h2B02}; cmds[57] = {1'b1, 16'h0001};
        cmds[58] = {1'b0, 16'h2B03}; cmds[59] = {1'b1, 16'h00DF}; // 479

        // --- Display ON ---
        cmds[60] = {1'b0, 16'h2900}; 

        cmds[61] = CMD_END;
    end

    // =========================================================
    // 4. LCD 状态机 (初始化 -> 刷屏循环)
    // =========================================================
    localparam H_RES = 800;
    localparam V_RES = 480;

    reg [3:0]  state;
    reg [31:0] timer;
    reg [8:0]  idx;
    
    reg [9:0]  px_x, px_y;
    reg [15:0] color;
    reg [1:0]  wr_phase;
    reg [4:0]  wr_cnt;

    // 为了画面稳定：每帧开始前把游戏状态打快照
    reg [1:0] car_lane_r, obs_lane_r, bonus_lane_r;
    reg [9:0] obs_x_r, bonus_x_r;
    reg       bonus_active_r;
    reg       game_over_r;
    reg       paused_r;

    // 颜色定义 (RGB565)
    localparam [15:0] RED    = 16'hF800;
    localparam [15:0] GREEN  = 16'h07E0;
    localparam [15:0] BLUE   = 16'h001F;
    localparam [15:0] WHITE  = 16'hFFFF;
    localparam [15:0] BLACK  = 16'h0000;
    localparam [15:0] YELLOW = 16'hFFE0; // 奖励用黄色

    // 额外颜色：像素风小车 & 面板
    localparam [15:0] CAR_BODY   = 16'hFCA0; // 橙红车身
    localparam [15:0] CAR_WINDOW = 16'h07FF; // 青色车窗
    localparam [15:0] CAR_WHEEL  = 16'h0000; // 黑色轮胎
    localparam [15:0] PANEL_BG   = 16'h2104; // 深灰面板背景
    localparam [15:0] PANEL_TEXT = 16'hFFFF; // 白色文字

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state    <= 0; timer <= 0; idx <= 0;
            lcd_rst  <= 1; lcd_wr <= 1; lcd_rs <= 0;
            px_x     <= 0; px_y <= 0;
            wr_phase <= 0;
            status   <= 0;
        end else begin
            case (state)
                // 0: 上电延时
                0: begin 
                    status <= 4'd0;
                    if (timer < 500_000) timer <= timer + 1;
                    else begin timer <= 0; state <= 1; end
                end
                
                // 1: 硬件复位脉冲 (Low)
                1: begin 
                    status  <= 4'd1;
                    lcd_rst <= 0;
                    if (timer < 200_000) timer <= timer + 1;
                    else begin lcd_rst <= 1; timer <= 0; state <= 2; end
                end

                // 2: 复位后恢复延时
                2: begin 
                    status <= 4'd3;
                    if (timer < 2_000_000) timer <= timer + 1;
                    else begin timer <= 0; idx <= 0; state <= 3; end
                end

                // 3: 发送初始化指令
                3: begin 
                    status <= 4'd2;
                    if (cmds[idx] == CMD_END) begin
                        state    <= 5; // 初始化完成，去刷屏
                        wr_phase <= 0;
                    end else if (idx == 39) begin // cmds[39] 的占位符 -> Sleep Out 延时
                        if (timer < 10_000_000) timer <= timer + 1; // 100ms
                        else begin timer <= 0; idx <= idx + 1; end
                    end else begin
                        lcd_rs <= cmds[idx][16];   // 0=Index, 1=Data
                        lcd_db <= cmds[idx][15:0];
                        lcd_wr <= 0;               // 拉低 WR
                        state  <= 4;
                    end
                end

                // 4: 保持 WR 低电平一个拍
                4: begin 
                    lcd_wr <= 1; // 拉高 WR
                    idx    <= idx + 1;
                    state  <= 3;
                end

                // 5: 发送写内存命令 (0x2C00)
                5: begin 
                    status <= 4'd4;
                    case(wr_phase)
                        0: begin 
                            lcd_rs   <= 0;        // Command
                            lcd_db   <= 16'h2C00; // Write RAM
                            lcd_wr   <= 0; 
                            wr_phase <= 1; 
                            wr_cnt   <= 0;
                        end
                        1: begin 
                            wr_cnt <= wr_cnt + 1;
                            if(wr_cnt == 5) begin 
                                lcd_wr   <= 1; 
                                wr_phase <= 2; 
                            end
                        end
                        2: begin 
                            // ★ 在开始新的一帧前打快照
                            car_lane_r     <= car_lane;
                            obs_lane_r     <= obs_lane;
                            obs_x_r        <= obs_x;
                            bonus_lane_r   <= bonus_lane;
                            bonus_x_r      <= bonus_x;
                            bonus_active_r <= bonus_active;
                            game_over_r    <= game_over;
                            paused_r       <= paused;

                            state    <= 6; // 准备开始发像素数据
                            px_x     <= 0; 
                            px_y     <= 0; 
                            wr_phase <= 0; 
                        end
                    endcase
                end

                // 6: 像素流式传输 (横版绘制逻辑)
                6: begin 
                    status <= 4'd4;
                    case(wr_phase)
                        // =================================================
                        // wr_phase 0: 计算当前像素颜色
                        // =================================================
                        0: begin
                            lcd_rs <= 1; // Data
                            
                            // 1. 默认背景
                            color <= BLACK;

                            // 2. 车道分割线
                            if (px_y == 10'd160 || px_y == 10'd320)
                                color <= WHITE;

                            // 3. 像素风小车（车头向右）
                            if (px_x >= 100 && px_x <= 180) begin
                                case (car_lane_r)
                                    // lane0: Y 50~110
                                    2'd0: if (px_y >= 50 && px_y <= 110) begin
                                        // 左右轮胎
                                        if ( ((px_x >= 100 && px_x <= 105) ||
                                              (px_x >= 175 && px_x <= 180)) &&
                                             (px_y >= 58  && px_y <= 102) )
                                            color <= CAR_WHEEL;
                                        // 前挡风玻璃（靠右）
                                        else if (px_x >= 150 && px_x <= 172 &&
                                                 px_y >= 70  && px_y <= 90)
                                            color <= CAR_WINDOW;
                                        // 车身
                                        else if (px_x >= 105 && px_x <= 175)
                                            color <= CAR_BODY;
                                    end
                                    // lane1: Y 210~270
                                    2'd1: if (px_y >= 210 && px_y <= 270) begin
                                        if ( ((px_x >= 100 && px_x <= 105) ||
                                              (px_x >= 175 && px_x <= 180)) &&
                                             (px_y >= 218 && px_y <= 262) )
                                            color <= CAR_WHEEL;
                                        else if (px_x >= 150 && px_x <= 172 &&
                                                 px_y >= 230 && px_y <= 250)
                                            color <= CAR_WINDOW;
                                        else if (px_x >= 105 && px_x <= 175)
                                            color <= CAR_BODY;
                                    end
                                    // lane2: Y 370~430
                                    2'd2: if (px_y >= 370 && px_y <= 430) begin
                                        if ( ((px_x >= 100 && px_x <= 105) ||
                                              (px_x >= 175 && px_x <= 180)) &&
                                             (px_y >= 378 && px_y <= 422) )
                                            color <= CAR_WHEEL;
                                        else if (px_x >= 150 && px_x <= 172 &&
                                                 px_y >= 390 && px_y <= 410)
                                            color <= CAR_WINDOW;
                                        else if (px_x >= 105 && px_x <= 175)
                                            color <= CAR_BODY;
                                    end
                                endcase
                            end

                            // 4. 障碍物 (蓝色)
                            if (px_x >= obs_x_r && px_x <= obs_x_r + 40) begin
                                if (obs_lane_r == 0 && px_y < 160)                     color <= BLUE;
                                if (obs_lane_r == 1 && px_y >= 160 && px_y < 320)     color <= BLUE;
                                if (obs_lane_r == 2 && px_y >= 320)                   color <= BLUE;
                            end

                            // 5. 奖励 (黄色)
                            if (bonus_active_r &&
                                px_x >= bonus_x_r && px_x <= bonus_x_r + 40) begin
                                if (bonus_lane_r == 0 && px_y < 160)                   color <= YELLOW;
                                if (bonus_lane_r == 1 && px_y >= 160 && px_y < 320)   color <= YELLOW;
                                if (bonus_lane_r == 2 && px_y >= 320)                 color <= YELLOW;
                            end

                            // 6. 文本面板 (GAME OVER / PAUSE)，字头在左，正常方向
                            if (game_over_r || paused_r) begin
                                // 面板背景 + 边框
                                if (px_x >= 200 && px_x <= 600 &&
                                    px_y >= 160 && px_y <= 320) begin
                                    if (px_x == 200 || px_x == 600 ||
                                        px_y == 160 || px_y == 320)
                                        color <= WHITE;
                                    else
                                        color <= PANEL_BG;
                                end

                                // ------------ GAME OVER ------------
                                if (game_over_r) begin
                                    // G
                                    if (px_x >= 220 && px_x < 260 &&
                                        px_y >= 180 && px_y < 220) begin
                                        if ( (px_y >= 180 && px_y <= 184 && px_x >= 224 && px_x <= 256) ||
                                             (px_y >= 216 && px_y <= 220 && px_x >= 224 && px_x <= 256) ||
                                             (px_x >= 220 && px_x <= 224 && px_y >= 184 && px_y <= 216) ||
                                             (px_x >= 252 && px_x <= 256 && px_y >= 200 && px_y <= 216) ||
                                             (px_y >= 198 && px_y <= 202 && px_x >= 236 && px_x <= 256) )
                                            color <= PANEL_TEXT;
                                    end
                                    // A
                                    if (px_x >= 270 && px_x < 310 &&
                                        px_y >= 180 && px_y < 220) begin
                                        if ( (px_y >= 180 && px_y <= 184 && px_x >= 274 && px_x <= 306) ||
                                             (px_y >= 198 && px_y <= 202 && px_x >= 274 && px_x <= 306) ||
                                             (px_x >= 270 && px_x <= 274 && px_y >= 184 && px_y <= 220) ||
                                             (px_x >= 306 && px_x <= 310 && px_y >= 184 && px_y <= 220) )
                                            color <= PANEL_TEXT;
                                    end
                                    // M
                                    if (px_x >= 320 && px_x < 360 &&
                                        px_y >= 180 && px_y < 220) begin
                                        if ( (px_x >= 320 && px_x <= 324 && px_y >= 180 && px_y <= 220) ||
                                             (px_x >= 356 && px_x <= 360 && px_y >= 180 && px_y <= 220) ||
                                             (px_x >= 332 && px_x <= 336 && px_y >= 188 && px_y <= 196) ||
                                             (px_x >= 344 && px_x <= 348 && px_y >= 188 && px_y <= 196) )
                                            color <= PANEL_TEXT;
                                    end
                                    // E
                                    if (px_x >= 370 && px_x < 410 &&
                                        px_y >= 180 && px_y < 220) begin
                                        if ( (px_x >= 370 && px_x <= 374 && px_y >= 180 && px_y <= 220) ||
                                             (px_y >= 180 && px_y <= 184 && px_x >= 374 && px_x <= 406) ||
                                             (px_y >= 198 && px_y <= 202 && px_x >= 374 && px_x <= 400) ||
                                             (px_y >= 216 && px_y <= 220 && px_x >= 374 && px_x <= 406) )
                                            color <= PANEL_TEXT;
                                    end

                                    // O
                                    if (px_x >= 250 && px_x < 290 &&
                                        px_y >= 240 && px_y < 280) begin
                                        if ( (px_y >= 240 && px_y <= 244 && px_x >= 254 && px_x <= 286) ||
                                             (px_y >= 276 && px_y <= 280 && px_x >= 254 && px_x <= 286) ||
                                             (px_x >= 250 && px_x <= 254 && px_y >= 244 && px_y <= 276) ||
                                             (px_x >= 286 && px_x <= 290 && px_y >= 244 && px_y <= 276) )
                                            color <= PANEL_TEXT;
                                    end
                                    // V
                                    if (px_x >= 300 && px_x < 340 &&
                                        px_y >= 240 && px_y < 280) begin
                                        if ( (px_x >= 300 && px_x <= 304 && px_y >= 240 && px_y <= 268) ||
                                             (px_x >= 336 && px_x <= 340 && px_y >= 240 && px_y <= 268) ||
                                             (px_x >= 312 && px_x <= 328 && px_y >= 268 && px_y <= 280) )
                                            color <= PANEL_TEXT;
                                    end
                                    // E
                                    if (px_x >= 350 && px_x < 390 &&
                                        px_y >= 240 && px_y < 280) begin
                                        if ( (px_x >= 350 && px_x <= 354 && px_y >= 240 && px_y <= 280) ||
                                             (px_y >= 240 && px_y <= 244 && px_x >= 354 && px_x <= 386) ||
                                             (px_y >= 258 && px_y <= 262 && px_x >= 354 && px_x <= 380) ||
                                             (px_y >= 276 && px_y <= 280 && px_x >= 354 && px_x <= 386) )
                                            color <= PANEL_TEXT;
                                    end
                                    // R
                                    if (px_x >= 400 && px_x < 440 &&
                                        px_y >= 240 && px_y < 280) begin
                                        if ( (px_x >= 400 && px_x <= 404 && px_y >= 240 && px_y <= 280) ||
                                             (px_y >= 240 && px_y <= 244 && px_x >= 404 && px_x <= 436) ||
                                             (px_y >= 258 && px_y <= 262 && px_x >= 404 && px_x <= 432) ||
                                             (px_x >= 432 && px_x <= 436 && px_y >= 244 && px_y <= 262) ||
                                             (px_x >= 420 && px_x <= 436 && px_y >= 262 && px_y <= 280) )
                                            color <= PANEL_TEXT;
                                    end
                                end

                                // ------------ PAUSE ------------
                                if (paused_r && !game_over_r) begin
                                    // P
                                    if (px_x >= 260 && px_x < 300 &&
                                        px_y >= 200 && px_y < 260) begin
                                        if ( (px_x >= 260 && px_x <= 264 && px_y >= 200 && px_y <= 260) ||
                                             (px_y >= 200 && px_y <= 204 && px_x >= 264 && px_x <= 296) ||
                                             (px_y >= 228 && px_y <= 232 && px_x >= 264 && px_x <= 296) ||
                                             (px_x >= 296 && px_x <= 300 && px_y >= 204 && px_y <= 228) )
                                            color <= PANEL_TEXT;
                                    end
                                    // A
                                    if (px_x >= 310 && px_x < 350 &&
                                        px_y >= 200 && px_y < 260) begin
                                        if ( (px_y >= 200 && px_y <= 204 && px_x >= 314 && px_x <= 346) ||
                                             (px_y >= 228 && px_y <= 232 && px_x >= 314 && px_x <= 346) ||
                                             (px_x >= 310 && px_x <= 314 && px_y >= 204 && px_y <= 260) ||
                                             (px_x >= 346 && px_x <= 350 && px_y >= 204 && px_y <= 260) )
                                            color <= PANEL_TEXT;
                                    end
                                    // U
                                    if (px_x >= 360 && px_x < 400 &&
                                        px_y >= 200 && px_y < 260) begin
                                        if ( (px_x >= 360 && px_x <= 364 && px_y >= 200 && px_y <= 252) ||
                                             (px_x >= 396 && px_x <= 400 && px_y >= 200 && px_y <= 252) ||
                                             (px_y >= 252 && px_y <= 256 && px_x >= 364 && px_x <= 396) )
                                            color <= PANEL_TEXT;
                                    end
                                    // S
                                    if (px_x >= 410 && px_x < 450 &&
                                        px_y >= 200 && px_y < 260) begin
                                        if ( (px_y >= 200 && px_y <= 204 && px_x >= 414 && px_x <= 446) ||
                                             (px_y >= 228 && px_y <= 232 && px_x >= 414 && px_x <= 446) ||
                                             (px_y >= 256 && px_y <= 260 && px_x >= 414 && px_x <= 446) ||
                                             (px_x >= 410 && px_x <= 414 && px_y >= 204 && px_y <= 228) ||
                                             (px_x >= 446 && px_x <= 450 && px_y >= 232 && px_y <= 256) )
                                            color <= PANEL_TEXT;
                                    end
                                    // E
                                    if (px_x >= 460 && px_x < 500 &&
                                        px_y >= 200 && px_y < 260) begin
                                        if ( (px_x >= 460 && px_x <= 464 && px_y >= 200 && px_y <= 260) ||
                                             (px_y >= 200 && px_y <= 204 && px_x >= 464 && px_x <= 496) ||
                                             (px_y >= 228 && px_y <= 232 && px_x >= 464 && px_x <= 492) ||
                                             (px_y >= 256 && px_y <= 260 && px_x >= 464 && px_x <= 496) )
                                            color <= PANEL_TEXT;
                                    end
                                end
                            end // if (game_over_r || paused_r)

                            // 输出像素
                            lcd_db   <= color;
                            lcd_wr   <= 0;     // 拉低 WR
                            wr_phase <= 1;
                            wr_cnt   <= 0;
                        end

                        // 保持 WR 低
                        1: begin 
                            wr_cnt <= wr_cnt + 1;
                            if(wr_cnt == 4) begin 
                                lcd_wr   <= 1; 
                                wr_phase <= 2; 
                            end
                        end

                        // 坐标递增
                        2: begin 
                            if (px_x < H_RES-1) begin
                                px_x <= px_x + 1;
                            end else begin
                                px_x <= 0;
                                if (px_y < V_RES-1) begin
                                    px_y <= px_y + 1;
                                end else begin
                                    px_y  <= 0;
                                    state <= 5; // 这一帧结束，回到 0x2C 准备下一帧
                                end
                            end
                            wr_phase <= 0;
                        end
                    endcase
                end
            endcase
        end
    end

endmodule
