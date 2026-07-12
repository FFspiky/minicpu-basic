// 游戏核心逻辑：横向卷轴赛车 + 计分 + 奖励 + 加速 + 暂停
module game_core1(
    input        clk,
    input        rst_n,
    input        tick_60hz,
    input        in_left,     // 左换道
    input        in_right,    // 右换道
    input        in_accel,    // 加速键（上键）
    input        in_pause,    // 暂停键（下键）
    input        in_start,    // 任意键开始
    input  [1:0] rand_in,     // LFSR 随机输入

    output reg [1:0]  car_lane,      // 0=上, 1=中, 2=下
    output reg [9:0]  obs_pos_x,
    output reg [1:0]  obs_lane,
    output reg [9:0]  bonus_pos_x,
    output reg [1:0]  bonus_lane,
    output reg        bonus_active,
    output reg        game_over,
    output reg [15:0] score,
    output reg paused
);

    // =============================================================
    // 参数与随机车道
    // =============================================================
    localparam [9:0] OBS_X_START = 10'd799;

    localparam [9:0] OBS_SPEED_NORMAL = 10'd8;    // 正常速度
    localparam [9:0] OBS_SPEED_FAST   = 10'd16;   // 加速速度

    localparam [15:0] SURVIVE_POINTS_PER_SEC = 16'd10; // 存活 1 秒 +10
    localparam [15:0] BONUS_POINTS           = 16'd50; // 奖励 +50

    wire [1:0] rand_lane_3 = rand_in % 3;

    // 当前速度（加速键决定）
    wire [9:0] cur_speed = in_accel ? OBS_SPEED_FAST : OBS_SPEED_NORMAL;


    // =============================================================
    // 状态机
    // =============================================================
    localparam S_IDLE  = 2'd0;
    localparam S_PLAY  = 2'd1;
    localparam S_CRASH = 2'd2;

    reg [1:0] state;


    // =============================================================
    // 按键事件（左/右/暂停）-- 防连跳 + 防抖
    // =============================================================
    localparam integer RELEASE_TH = 23'd2_000_000;  //20ms

    reg left_seen, right_seen, pause_seen;
    reg [22:0] left_zero_cnt, right_zero_cnt, pause_zero_cnt;
    reg left_event, right_event, pause_event;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            left_seen  <= 1'b0;
            right_seen <= 1'b0;
            pause_seen <= 1'b0;
            left_zero_cnt  <= 0;
            right_zero_cnt <= 0;
            pause_zero_cnt <= 0;
            left_event  <= 0;
            right_event <= 0;
            pause_event <= 0;
        end else begin
            left_event  <= 0;
            right_event <= 0;
            pause_event <= 0;

            // 左键
            if (in_left) begin
                left_zero_cnt <= 0;
                if (!left_seen) begin
                    left_seen  <= 1;
                    left_event <= 1;
                end
            end else begin
                if (left_zero_cnt < RELEASE_TH) left_zero_cnt <= left_zero_cnt + 1;
                if (left_zero_cnt >= RELEASE_TH) left_seen <= 0;
            end

            // 右键
            if (in_right) begin
                right_zero_cnt <= 0;
                if (!right_seen) begin
                    right_seen  <= 1;
                    right_event <= 1;
                end
            end else begin
                if (right_zero_cnt < RELEASE_TH) right_zero_cnt <= right_zero_cnt + 1;
                if (right_zero_cnt >= RELEASE_TH) right_seen <= 0;
            end

            // 暂停键
            if (in_pause) begin
                pause_zero_cnt <= 0;
                if (!pause_seen) begin
                    pause_seen  <= 1;
                    pause_event <= 1;   // 事件脉冲
                end
            end else begin
                if (pause_zero_cnt < RELEASE_TH) pause_zero_cnt <= pause_zero_cnt + 1;
                if (pause_zero_cnt >= RELEASE_TH) pause_seen <= 0;
            end
        end
    end


    // =============================================================
    // 游戏主逻辑
    // =============================================================
    reg bonus_hit;
    reg [5:0] sec_cnt;    // 60 tick = 1秒
    reg paused;           // 暂停标志

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state        <= S_IDLE;
            car_lane     <= 2'd1;
            obs_pos_x    <= OBS_X_START;
            obs_lane     <= 2'd0;
            bonus_pos_x  <= OBS_X_START;
            bonus_lane   <= 2'd0;
            bonus_active <= 0;
            bonus_hit    <= 0;
            paused       <= 0;
            game_over    <= 0;
            score        <= 0;
            sec_cnt      <= 0;
        end else begin

            case (state)

                // -------------------------------------------------
                // 等待开始
                // -------------------------------------------------
                S_IDLE: begin
                    game_over    <= 0;
                    bonus_active <= 0;
                    bonus_hit    <= 0;
                    paused       <= 0;
                    sec_cnt      <= 0;

                    if (in_start) begin
                        state        <= S_PLAY;
                        car_lane     <= 1;
                        obs_pos_x    <= OBS_X_START;
                        obs_lane     <= rand_lane_3;
                        score        <= 0;
                    end
                end


                // -------------------------------------------------
                // 游戏进行
                // -------------------------------------------------
                S_PLAY: begin
                    // 暂停切换
                    if (pause_event)
                        paused <= ~paused;

                    // 左右换道
                    if (left_event  && car_lane > 0) car_lane <= car_lane - 1;
                    if (right_event && car_lane < 2) car_lane <= car_lane + 1;

                    // 游戏核心更新（暂停时停止）
                    if (tick_60hz && !paused) begin
                        bonus_hit <= 0;

                        // ---------- 障碍物移动 ----------
                        if (obs_pos_x > 10'd10) begin
                            obs_pos_x <= obs_pos_x - cur_speed;
                        end else begin
                            obs_pos_x <= OBS_X_START;
                            obs_lane  <= rand_lane_3;

                            // 障碍重生 -> 有概率生成奖励
                            if (!bonus_active && rand_in == 2'b01) begin
                                bonus_active <= 1;
                                bonus_lane   <= (rand_lane_3 == 2'd2) ? 0 : (rand_lane_3 + 1);
                                bonus_pos_x  <= OBS_X_START;
                            end
                        end

                        // ---------- 奖励移动 ----------
                        if (bonus_active) begin
                            if (bonus_pos_x > 10'd10) begin
                                bonus_pos_x <= bonus_pos_x - cur_speed;
                            end else begin
                                bonus_active <= 0;
                            end
                        end

                        // ---------- 碰撞检测：障碍 ----------
                        if (car_lane == obs_lane &&
                            obs_pos_x < 160 && obs_pos_x > 60)
                        begin
                            state     <= S_CRASH;
                        end

                        // ---------- 碰撞检测：奖励 ----------
                        if (bonus_active && car_lane == bonus_lane &&
                            bonus_pos_x < 160 && bonus_pos_x > 60)
                        begin
                            bonus_active <= 0;
                            bonus_hit    <= 1;
                        end

                        // ---------- 计分：生存时间 ----------
                        if (sec_cnt == 59) begin
                            sec_cnt <= 0;
                            score   <= score + SURVIVE_POINTS_PER_SEC;
                        end else begin
                            sec_cnt <= sec_cnt + 1;
                        end

                        // ---------- 计分：奖励 +50 ----------
                        if (bonus_hit) begin
                            score <= score + BONUS_POINTS;
                        end
                    end
                end


                // -------------------------------------------------
                // 撞车
                // -------------------------------------------------
                S_CRASH: begin
                    game_over <= 1;
                    paused    <= 0;
                end

            endcase
        end
    end

endmodule
