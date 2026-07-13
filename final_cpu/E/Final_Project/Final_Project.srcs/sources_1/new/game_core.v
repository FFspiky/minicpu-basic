module game_core(
    input clk,
    input rst_n,
    input tick_60hz, // 游戏逻辑刷新时钟
    input in_left, in_right, in_up, in_down,
    input [1:0] rand_in,
    output reg [1:0] car_lane, // 0:左, 1:中, 2:右
    output reg [9:0] car_pos_x, // 物理X轴位置
    output reg [1:0] obs_lane,
    output reg [9:0] obs_pos_x,
    output reg game_over
);
    localparam S_IDLE = 2'b00;
    localparam S_PLAY = 2'b01;
    localparam S_CRASH = 2'b10;
    reg [1:0] state;
    reg left_d, right_d;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE;
            car_lane <= 1;
            car_pos_x <= 100;
            obs_lane <= 0;
            obs_pos_x <= 480;
            game_over <= 0;
        end else begin
            left_d <= in_left;
            right_d <= in_right;
            wire left_pulse = in_left & ~left_d;
            wire right_pulse = in_right & ~right_d;

            case (state)
                S_IDLE: begin
                    if (left_pulse || right_pulse) state <= S_PLAY;
                    game_over <= 0;
                end
                S_PLAY: begin
                    // 左右变道
                    if (left_pulse && car_lane > 0) car_lane <= car_lane - 1;
                    if (right_pulse && car_lane < 2) car_lane <= car_lane + 1;
                    
                    if (tick_60hz) begin
                        // 前后移动
                        if (in_up && car_pos_x < 300) car_pos_x <= car_pos_x + 2;
                        if (in_down && car_pos_x > 20) car_pos_x <= car_pos_x - 2;
                        
                        // 障碍物移动
                        obs_pos_x <= obs_pos_x - 4;
                        if (obs_pos_x < 10 || obs_pos_x > 500) begin
                            obs_pos_x <= 480;
                            obs_lane <= rand_in % 3;
                        end
                        
                        // 碰撞检测
                        if (car_lane == obs_lane) begin
                            if ((obs_pos_x >= car_pos_x && obs_pos_x <= car_pos_x + 40) ||
                                (obs_pos_x + 30 >= car_pos_x && obs_pos_x + 30 <= car_pos_x + 40)) begin
                                state <= S_CRASH;
                            end
                        end
                    end
                end
                S_CRASH: begin
                    game_over <= 1;
                    if (left_pulse || right_pulse) begin
                        state <= S_IDLE;
                        car_lane <= 1;
                        car_pos_x <= 100;
                        obs_pos_x <= 480;
                    end
                end
            endcase
        end
    end
endmodule