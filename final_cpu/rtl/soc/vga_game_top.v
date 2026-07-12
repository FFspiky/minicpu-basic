`timescale 1ns / 1ps
`default_nettype none

module vga_game_top(
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
    input  wire [19:0] current_score_bcd,
    input  wire [159:0] leaderboard_bcd_scores,
    input  wire [3:0]  leaderboard_count,
    output wire        vga_hsync,
    output wire        vga_vsync,
    output wire [3:0]  vga_r,
    output wire [3:0]  vga_g,
    output wire [3:0]  vga_b
);
    localparam H_ACTIVE = 640;
    localparam H_FRONT  = 16;
    localparam H_SYNC   = 96;
    localparam H_TOTAL  = 800;
    localparam V_ACTIVE = 480;
    localparam V_FRONT  = 10;
    localparam V_SYNC   = 2;
    localparam V_TOTAL  = 525;

    reg [1:0] pixel_div;
    reg [9:0] h_count;
    reg [9:0] v_count;
    reg [9:0] rotated_game_x;
    reg [1:0] rotated_x_phase;
    reg [8:0] rotated_game_y;
    reg [5:0] rotated_y_phase;
    wire pixel_ce = (pixel_div == 2'd3);
    wire [2:0] rotated_x_phase_sum = {1'b0, rotated_x_phase} + 3'd5;
    wire [6:0] rotated_y_phase_sum = {1'b0, rotated_y_phase} + 7'd60;

    wire [1:0] cdc_car_lane;
    wire [8:0] cdc_car_y;
    wire [1:0] cdc_obs_lane;
    wire [9:0] cdc_obs_x;
    wire       cdc_obs_active;
    wire [1:0] cdc_obs1_lane;
    wire [9:0] cdc_obs1_x;
    wire       cdc_obs1_active;
    wire [1:0] cdc_obs2_lane;
    wire [9:0] cdc_obs2_x;
    wire       cdc_obs2_active;
    wire [1:0] cdc_bonus_lane;
    wire [9:0] cdc_bonus_x;
    wire       cdc_bonus_active;
    wire       cdc_game_enable;
    wire       cdc_paused;
    wire       cdc_game_over;
    wire       cdc_bg_enable;
    wire       cdc_waiting_start;
    wire [4:0] cdc_difficulty_level;
    wire [15:0] cdc_score;
    wire [15:0] cdc_speed_q8;

    reg [1:0] render_car_lane;
    reg [8:0] render_car_y;
    reg [1:0] render_obs_lane;
    reg [9:0] render_obs_x;
    reg       render_obs_active;
    reg [1:0] render_obs1_lane;
    reg [9:0] render_obs1_x;
    reg       render_obs1_active;
    reg [1:0] render_obs2_lane;
    reg [9:0] render_obs2_x;
    reg       render_obs2_active;
    reg [1:0] render_bonus_lane;
    reg [9:0] render_bonus_x;
    reg       render_bonus_active;
    reg       render_game_enable;
    reg       render_paused;
    reg       render_game_over;
    reg       render_bg_enable;
    reg       render_waiting_start;
    reg [4:0] render_difficulty_level;
    reg [15:0] render_score;
    reg [15:0] render_speed_q8;
    reg [17:0] bg_scroll_q8;
    reg [19:0] render_current_score_bcd;
    reg [159:0] render_leaderboard_bcd_scores;
    reg [3:0] render_leaderboard_count;
    reg [15:0] sidebar_pixel_latched;
    wire [15:0] sidebar_pixel_color;

    game_state_cdc u_game_state_cdc(
        .clk(clk), .resetn(resetn),
        .game_car(game_car), .game_obs(game_obs), .game_obs1(game_obs1),
        .game_obs2(game_obs2), .game_bonus(game_bonus),
        .game_flags(game_flags), .game_score(game_score),
        .game_commit_toggle(game_commit_toggle),
        .car_lane(cdc_car_lane), .car_y(cdc_car_y),
        .obs_lane(cdc_obs_lane), .obs_x(cdc_obs_x), .obs_active(cdc_obs_active),
        .obs1_lane(cdc_obs1_lane), .obs1_x(cdc_obs1_x), .obs1_active(cdc_obs1_active),
        .obs2_lane(cdc_obs2_lane), .obs2_x(cdc_obs2_x), .obs2_active(cdc_obs2_active),
        .bonus_lane(cdc_bonus_lane), .bonus_x(cdc_bonus_x), .bonus_active(cdc_bonus_active),
        .game_enable(cdc_game_enable), .paused(cdc_paused), .game_over(cdc_game_over),
        .bg_enable(cdc_bg_enable), .backlight_enable(), .waiting_start(cdc_waiting_start),
        .difficulty_level(cdc_difficulty_level), .score(cdc_score),
        .speed_level(), .speed_q8(cdc_speed_q8),
        .commit_ack(), .commit_ack_toggle()
    );

    always @(posedge clk or negedge resetn)
    begin
        if (!resetn)
        begin
            pixel_div <= 2'd0;
            h_count <= 10'd0;
            v_count <= 10'd0;
            rotated_game_x <= 10'd799;
            rotated_x_phase <= 2'd0;
            rotated_game_y <= 9'd0;
            rotated_y_phase <= 6'd0;
            render_car_lane <= 2'd1;
            render_car_y <= 9'd210;
            render_obs_lane <= 2'd0;
            render_obs_x <= 10'd799;
            render_obs_active <= 1'b0;
            render_obs1_lane <= 2'd1;
            render_obs1_x <= 10'd799;
            render_obs1_active <= 1'b0;
            render_obs2_lane <= 2'd2;
            render_obs2_x <= 10'd799;
            render_obs2_active <= 1'b0;
            render_bonus_lane <= 2'd1;
            render_bonus_x <= 10'd799;
            render_bonus_active <= 1'b0;
            render_game_enable <= 1'b1;
            render_paused <= 1'b0;
            render_game_over <= 1'b0;
            render_bg_enable <= 1'b1;
            render_waiting_start <= 1'b1;
            render_difficulty_level <= 5'd0;
            render_score <= 16'd0;
            render_speed_q8 <= 16'd0;
            bg_scroll_q8 <= 18'd0;
            render_current_score_bcd <= 20'd0;
            render_leaderboard_bcd_scores <= 160'd0;
            render_leaderboard_count <= 4'd0;
            sidebar_pixel_latched <= 16'd0;
        end
        else
        begin
            pixel_div <= pixel_div + 1'b1;
            if (pixel_ce)
            begin
                sidebar_pixel_latched <= sidebar_pixel_color;
                if (h_count == H_TOTAL - 1)
                begin
                    h_count <= 10'd0;
                    if (v_count == V_TOTAL - 1)
                    begin
                        v_count <= 10'd0;
                        rotated_game_x <= 10'd799;
                        rotated_x_phase <= 2'd0;
                        render_car_lane <= cdc_car_lane;
                        render_car_y <= cdc_car_y;
                        render_obs_lane <= cdc_obs_lane;
                        render_obs_x <= cdc_obs_x;
                        render_obs_active <= cdc_obs_active;
                        render_obs1_lane <= cdc_obs1_lane;
                        render_obs1_x <= cdc_obs1_x;
                        render_obs1_active <= cdc_obs1_active;
                        render_obs2_lane <= cdc_obs2_lane;
                        render_obs2_x <= cdc_obs2_x;
                        render_obs2_active <= cdc_obs2_active;
                        render_bonus_lane <= cdc_bonus_lane;
                        render_bonus_x <= cdc_bonus_x;
                        render_bonus_active <= cdc_bonus_active;
                        render_game_enable <= cdc_game_enable;
                        render_paused <= cdc_paused;
                        render_game_over <= cdc_game_over;
                        render_bg_enable <= cdc_bg_enable;
                        render_waiting_start <= cdc_waiting_start;
                        render_difficulty_level <= cdc_difficulty_level;
                        render_score <= cdc_score;
                        render_speed_q8 <= cdc_speed_q8;
                        render_current_score_bcd <= current_score_bcd;
                        render_leaderboard_bcd_scores <= leaderboard_bcd_scores;
                        render_leaderboard_count <= leaderboard_count;
                        if (cdc_game_enable && !cdc_paused && !cdc_game_over && !cdc_waiting_start)
                            bg_scroll_q8 <= bg_scroll_q8 + {2'b00, cdc_speed_q8};
                    end
                    else
                    begin
                        v_count <= v_count + 1'b1;
                        if (v_count < V_ACTIVE - 1)
                        begin
                            if (rotated_x_phase_sum >= 3'd6)
                            begin
                                rotated_game_x <= rotated_game_x - 10'd2;
                                rotated_x_phase <= rotated_x_phase_sum - 3'd6;
                            end
                            else
                            begin
                                rotated_game_x <= rotated_game_x - 10'd1;
                                rotated_x_phase <= rotated_x_phase_sum - 3'd3;
                            end
                        end
                    end
                end
                else
                begin
                    h_count <= h_count + 1'b1;
                    if (h_count < 10'd343)
                    begin
                        if (rotated_y_phase_sum >= 7'd86)
                        begin
                            rotated_game_y <= rotated_game_y + 9'd2;
                            rotated_y_phase <= rotated_y_phase_sum - 7'd86;
                        end
                        else
                        begin
                            rotated_game_y <= rotated_game_y + 9'd1;
                            rotated_y_phase <= rotated_y_phase_sum - 7'd43;
                        end
                    end
                end

                if (h_count == H_TOTAL - 1)
                begin
                    rotated_game_y <= 9'd0;
                    rotated_y_phase <= 6'd0;
                end
            end
        end
    end

    wire active_video = (h_count < H_ACTIVE) && (v_count < V_ACTIVE);
    wire game_region = active_video && (h_count < 10'd344);
    wire sidebar_region = active_video && (h_count >= 10'd352);
    wire [9:0] game_x = (v_count == 10'd479) ? 10'd0 : rotated_game_x;
    wire [8:0] game_y = (h_count == 10'd343) ? 9'd479 : rotated_game_y;
    wire [15:0] game_pixel_color;
    wire [9:0] sidebar_x_wide = h_count - 10'd352;

    racing_pixel_renderer u_renderer(
        .x(game_x), .y(game_y), .bg_scroll(bg_scroll_q8[17:8]),
        .car_lane(render_car_lane), .car_y(render_car_y),
        .obs_lane(render_obs_lane), .obs_x(render_obs_x), .obs_active(render_obs_active),
        .obs1_lane(render_obs1_lane), .obs1_x(render_obs1_x), .obs1_active(render_obs1_active),
        .obs2_lane(render_obs2_lane), .obs2_x(render_obs2_x), .obs2_active(render_obs2_active),
        .bonus_lane(render_bonus_lane), .bonus_x(render_bonus_x), .bonus_active(render_bonus_active),
        .game_enable(render_game_enable), .paused(render_paused), .game_over(render_game_over),
        .waiting_start(render_waiting_start), .bg_enable(render_bg_enable),
        .score(render_score), .speed_q8(render_speed_q8),
        .difficulty_level(render_difficulty_level), .pixel(game_pixel_color)
    );

    vga_scoreboard_renderer u_scoreboard_renderer(
        .x(sidebar_x_wide[8:0]), .y(v_count[8:0]),
        .current_score_bcd(render_current_score_bcd),
        .scores_bcd_packed(render_leaderboard_bcd_scores),
        .score_count(render_leaderboard_count),
        .pixel(sidebar_pixel_color)
    );

    wire [15:0] pixel_color = game_region ? game_pixel_color :
                              sidebar_region ? sidebar_pixel_latched : 16'h0000;

    assign vga_hsync = ~((h_count >= H_ACTIVE + H_FRONT) &&
                         (h_count < H_ACTIVE + H_FRONT + H_SYNC));
    assign vga_vsync = ~((v_count >= V_ACTIVE + V_FRONT) &&
                         (v_count < V_ACTIVE + V_FRONT + V_SYNC));
    assign vga_r = active_video ? pixel_color[15:12] : 4'd0;
    assign vga_g = active_video ? pixel_color[10:7]  : 4'd0;
    assign vga_b = active_video ? pixel_color[4:1]   : 4'd0;
endmodule

`default_nettype wire
