`timescale 1ns / 1ps
`default_nettype none

module game_state_cdc(
    input  wire        clk,
    input  wire        resetn,

    input  wire [31:0] game_car,
    input  wire [31:0] game_obs,
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
    output reg         commit_ack_toggle
);

    reg commit_sync0;
    reg commit_sync1;
    reg commit_sync2;
    reg [1:0] settle_cnt;

    wire [11:0] obs_x_raw   = game_obs[15:4];
    wire [11:0] bonus_x_raw = game_bonus[15:4];

    always @(posedge clk or negedge resetn)
    begin
        if (!resetn)
        begin
            commit_sync0      <= 1'b0;
            commit_sync1      <= 1'b0;
            commit_sync2      <= 1'b0;
            settle_cnt        <= 2'd0;
            car_lane          <= 2'd1;
            obs_lane          <= 2'd0;
            obs_x             <= 10'd799;
            obs_active        <= 1'b1;
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
            commit_ack_toggle <= 1'b0;
        end
        else
        begin
            commit_sync0 <= game_commit_toggle;
            commit_sync1 <= commit_sync0;
            commit_sync2 <= commit_sync1;

            if (commit_sync1 != commit_sync2)
            begin
                settle_cnt <= 2'd2;
            end
            else if (settle_cnt != 2'd0)
            begin
                settle_cnt <= settle_cnt - 2'd1;
                if (settle_cnt == 2'd1)
                begin
                    car_lane         <= (game_car[1:0] > 2'd2) ? 2'd2 : game_car[1:0];
                    obs_lane         <= (game_obs[1:0] > 2'd2) ? 2'd2 : game_obs[1:0];
                    obs_x            <= (obs_x_raw > 12'd799) ? 10'd799 : obs_x_raw[9:0];
                    obs_active       <= game_obs[31];
                    bonus_lane       <= (game_bonus[1:0] > 2'd2) ? 2'd2 : game_bonus[1:0];
                    bonus_x          <= (bonus_x_raw > 12'd799) ? 10'd799 : bonus_x_raw[9:0];
                    bonus_active     <= game_bonus[31];
                    game_enable      <= game_flags[0];
                    paused           <= game_flags[1];
                    game_over        <= game_flags[2];
                    bg_enable        <= game_flags[3];
                    backlight_enable <= game_flags[4];
                    score            <= game_score[15:0];
                    speed_level      <= game_score[31:16];
                    commit_ack_toggle <= commit_sync2;
                end
            end
        end
    end

endmodule

`default_nettype wire
