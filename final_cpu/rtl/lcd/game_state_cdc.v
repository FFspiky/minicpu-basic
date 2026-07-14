`timescale 1ns / 1ps
`default_nettype none

module game_state_cdc(
    input  wire        clk,
    input  wire        resetn,

    input  wire [31:0] game_car,
    input  wire [31:0] game_obs,
    input  wire [31:0] game_obs1,
    input  wire [31:0] game_obs2,
    input  wire [31:0] game_bonus,
    input  wire [31:0] game_flags,
    input  wire [31:0] game_score,
    input  wire        game_commit_toggle,

    output reg  [1:0]  car_lane,
    output reg  [1:0]  obs_lane,
    output reg  [9:0]  obs_x,
    output reg         obs_active,
    output reg  [1:0]  bonus_lane,
    output reg  [9:0]  bonus_x,
    output reg         bonus_active,
    output reg         game_enable,
    output reg         paused,
    output reg         game_over,
    output reg         bg_enable,
    output reg         backlight_enable,
    output reg  [15:0] score,
    output reg  [15:0] speed_level,
    output reg  [8:0]  car_y,
    output reg  [1:0]  obs1_lane,
    output reg  [9:0]  obs1_x,
    output reg         obs1_active,
    output reg  [1:0]  obs2_lane,
    output reg  [9:0]  obs2_x,
    output reg         obs2_active,
    output reg         waiting_start,
    output reg  [4:0]  difficulty_level,
    output reg  [15:0] speed_q8,
    output reg         commit_ack,
    output reg         commit_ack_toggle
);

    localparam [1:0] CAPTURE_IDLE   = 2'd0;
    localparam [1:0] CAPTURE_WAIT   = 2'd1;
    localparam [1:0] CAPTURE_SAMPLE = 2'd2;
    localparam [1:0] CAPTURE_VERIFY = 2'd3;

    (* ASYNC_REG = "TRUE" *) reg commit_sync0;
    (* ASYNC_REG = "TRUE" *) reg commit_sync1;
    (* ASYNC_REG = "TRUE" *) reg commit_sync2;
    reg [1:0] capture_state;
    reg [1:0] settle_cnt;
    reg [31:0] sample_car;
    reg [31:0] sample_obs;
    reg [31:0] sample_obs1;
    reg [31:0] sample_obs2;
    reg [31:0] sample_bonus;
    reg [31:0] sample_flags;
    reg [31:0] sample_score;

    wire [11:0] obs_x_raw   = game_obs[15:4];
    wire [11:0] obs1_x_raw  = game_obs1[15:4];
    wire [11:0] obs2_x_raw  = game_obs2[15:4];
    wire [11:0] bonus_x_raw = game_bonus[15:4];
    wire        commit_edge = commit_sync1 ^ commit_sync2;

    function [1:0] clamp_lane;
        input [1:0] lane_raw;
        begin
            clamp_lane = (lane_raw > 2'd2) ? 2'd2 : lane_raw;
        end
    endfunction

    function [9:0] clamp_x10;
        input [11:0] x_raw;
        begin
            clamp_x10 = (x_raw > 12'd799) ? 10'd799 : x_raw[9:0];
        end
    endfunction

    function [8:0] clamp_car_y;
        input [11:0] y_raw;
        begin
            clamp_car_y = (y_raw > 12'd419) ? 9'd419 : y_raw[8:0];
        end
    endfunction

    always @(posedge clk or negedge resetn)
    begin
        if (!resetn)
        begin
            commit_sync0      <= 1'b0;
            commit_sync1      <= 1'b0;
            commit_sync2      <= 1'b0;
            capture_state     <= CAPTURE_IDLE;
            settle_cnt        <= 2'd0;
            sample_car        <= 32'd0;
            sample_obs        <= 32'd0;
            sample_obs1       <= 32'd0;
            sample_obs2       <= 32'd0;
            sample_bonus      <= 32'd0;
            sample_flags      <= 32'd0;
            sample_score      <= 32'd0;
            car_lane          <= 2'd1;
            obs_lane          <= 2'd0;
            obs_x             <= 10'd799;
            obs_active        <= 1'b0;
            bonus_lane        <= 2'd1;
            bonus_x           <= 10'd799;
            bonus_active      <= 1'b0;
            game_enable       <= 1'b1;
            paused            <= 1'b0;
            game_over         <= 1'b0;
            bg_enable         <= 1'b1;
            backlight_enable  <= 1'b1;
            score             <= 16'd0;
            speed_level       <= 16'd0;
            car_y             <= 12'd210;
            obs1_lane         <= 2'd1;
            obs1_x            <= 10'd799;
            obs1_active       <= 1'b0;
            obs2_lane         <= 2'd2;
            obs2_x            <= 10'd799;
            obs2_active       <= 1'b0;
            waiting_start     <= 1'b1;
            difficulty_level  <= 5'd0;
            speed_q8          <= 16'd0;
            commit_ack        <= 1'b0;
            commit_ack_toggle <= 1'b0;
        end
        else
        begin
            commit_sync0 <= game_commit_toggle;
            commit_sync1 <= commit_sync0;
            commit_sync2 <= commit_sync1;
            commit_ack   <= 1'b0;

            if (commit_edge)
            begin
                capture_state <= CAPTURE_WAIT;
                settle_cnt <= 2'd2;
            end
            else
            begin
                case (capture_state)
                    CAPTURE_IDLE:
                    begin
                        settle_cnt <= 2'd0;
                    end

                    CAPTURE_WAIT:
                    begin
                        if (settle_cnt != 2'd0)
                        begin
                            settle_cnt <= settle_cnt - 2'd1;
                        end
                        else
                        begin
                            capture_state <= CAPTURE_SAMPLE;
                        end
                    end

                    CAPTURE_SAMPLE:
                    begin
                        sample_car    <= game_car;
                        sample_obs    <= game_obs;
                        sample_obs1   <= game_obs1;
                        sample_obs2   <= game_obs2;
                        sample_bonus  <= game_bonus;
                        sample_flags  <= game_flags;
                        sample_score  <= game_score;
                        capture_state <= CAPTURE_VERIFY;
                    end

                    CAPTURE_VERIFY:
                    begin
                        if (sample_car   == game_car   &&
                            sample_obs   == game_obs   &&
                            sample_obs1  == game_obs1  &&
                            sample_obs2  == game_obs2  &&
                            sample_bonus == game_bonus &&
                            sample_flags == game_flags &&
                            sample_score == game_score)
                        begin
                            car_lane          <= clamp_lane(game_car[1:0]);
                            obs_lane          <= clamp_lane(game_obs[1:0]);
                            obs_x             <= clamp_x10(obs_x_raw);
                            obs_active        <= game_obs[31];
                            bonus_lane        <= clamp_lane(game_bonus[1:0]);
                            bonus_x           <= clamp_x10(bonus_x_raw);
                            bonus_active      <= game_bonus[31];
                            game_enable       <= game_flags[0];
                            paused            <= game_flags[1];
                            game_over         <= game_flags[2];
                            bg_enable         <= game_flags[3];
                            backlight_enable  <= game_flags[4];
                            score             <= game_score[15:0];
                            speed_level       <= game_score[31:16];

                            car_y             <= clamp_car_y(game_car[15:4]);
                            obs1_lane         <= clamp_lane(game_obs1[1:0]);
                            obs1_x            <= clamp_x10(obs1_x_raw);
                            obs1_active       <= game_obs1[31];
                            obs2_lane         <= clamp_lane(game_obs2[1:0]);
                            obs2_x            <= clamp_x10(obs2_x_raw);
                            obs2_active       <= game_obs2[31];
                            waiting_start     <= game_flags[5];
                            difficulty_level  <= game_flags[10:6];
                            speed_q8          <= game_score[31:16];
                            commit_ack        <= 1'b1;
                            commit_ack_toggle <= commit_sync2;
                            capture_state     <= CAPTURE_IDLE;
                        end
                        else
                        begin
                            sample_car   <= game_car;
                            sample_obs   <= game_obs;
                            sample_obs1  <= game_obs1;
                            sample_obs2  <= game_obs2;
                            sample_bonus <= game_bonus;
                            sample_flags <= game_flags;
                            sample_score <= game_score;
                        end
                    end

                    default:
                    begin
                        capture_state <= CAPTURE_IDLE;
                    end
                endcase
            end
        end
    end

endmodule

`default_nettype wire
