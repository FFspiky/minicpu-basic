`timescale 1ns / 1ps
`default_nettype none

module lcd_game_top #(
    parameter SIMULATION = 1'b0,
    parameter integer LCD_CONTROLLER = 0,
    parameter integer LEADERBOARD_MODE = 0,
    parameter integer H_RES = 800,
    parameter integer V_RES = 480
)(
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
    input  wire [159:0] leaderboard_bcd_scores,
    input  wire [3:0]  leaderboard_count,
    output wire [31:0] lcd_status,

    output wire        lcd_rst,
    output wire        lcd_cs,
    output wire        lcd_rs,
    output wire        lcd_wr,
    output wire        lcd_rd,
    inout  wire [15:0] lcd_data_io,
    output wire        lcd_bl_ctr,

    inout  wire        ct_int,
    inout  wire        ct_sda,
    output wire        ct_scl,
    output wire        ct_rstn
);

    localparam [1:0] DEFAULT_CAR_LANE   = 2'd1;
    localparam [1:0] DEFAULT_OBS_LANE   = 2'd0;
    localparam [1:0] DEFAULT_BONUS_LANE = 2'd1;
    localparam [9:0] DEFAULT_OBJ_X      = 10'd799;

    wire [1:0]  cdc_car_lane;
    wire [8:0]  cdc_car_y;
    wire [1:0]  cdc_obs_lane;
    wire [9:0]  cdc_obs_x;
    wire        cdc_obs_active;
    wire [1:0]  cdc_obs1_lane;
    wire [9:0]  cdc_obs1_x;
    wire        cdc_obs1_active;
    wire [1:0]  cdc_obs2_lane;
    wire [9:0]  cdc_obs2_x;
    wire        cdc_obs2_active;
    wire [1:0]  cdc_bonus_lane;
    wire [9:0]  cdc_bonus_x;
    wire        cdc_bonus_active;
    wire        cdc_game_enable;
    wire        cdc_paused;
    wire        cdc_game_over;
    wire        cdc_bg_enable;
    wire        cdc_backlight_enable;
    wire        cdc_waiting_start;
    wire [4:0]  cdc_difficulty_level;
    wire [15:0] cdc_score;
    wire [15:0] cdc_speed_q8;
    wire        commit_ack_toggle;

    reg  [1:0]  pend_car_lane;
    reg  [8:0]  pend_car_y;
    reg  [1:0]  pend_obs_lane;
    reg  [9:0]  pend_obs_x;
    reg         pend_obs_active;
    reg  [1:0]  pend_obs1_lane;
    reg  [9:0]  pend_obs1_x;
    reg         pend_obs1_active;
    reg  [1:0]  pend_obs2_lane;
    reg  [9:0]  pend_obs2_x;
    reg         pend_obs2_active;
    reg  [1:0]  pend_bonus_lane;
    reg  [9:0]  pend_bonus_x;
    reg         pend_bonus_active;
    reg         pend_game_enable;
    reg         pend_paused;
    reg         pend_game_over;
    reg         pend_bg_enable;
    reg         pend_backlight_enable;
    reg         pend_waiting_start;
    reg  [4:0]  pend_difficulty_level;
    reg  [15:0] pend_score;
    reg  [15:0] pend_speed_q8;

    reg  [1:0]  render_car_lane;
    reg  [8:0]  render_car_y;
    reg  [1:0]  render_obs_lane;
    reg  [9:0]  render_obs_x;
    reg         render_obs_active;
    reg  [1:0]  render_obs1_lane;
    reg  [9:0]  render_obs1_x;
    reg         render_obs1_active;
    reg  [1:0]  render_obs2_lane;
    reg  [9:0]  render_obs2_x;
    reg         render_obs2_active;
    reg  [1:0]  render_bonus_lane;
    reg  [9:0]  render_bonus_x;
    reg         render_bonus_active;
    reg         render_game_enable;
    reg         render_paused;
    reg         render_game_over;
    reg         render_waiting_start;
    reg  [4:0]  render_difficulty_level;
    reg         render_bg_enable;
    reg  [15:0] render_score;
    reg  [15:0] render_speed_q8;
    reg  [159:0] render_leaderboard_bcd_scores;
    reg  [3:0]   render_leaderboard_count;

    game_state_cdc u_game_state_cdc(
        .clk                (clk),
        .resetn             (resetn),
        .game_car           (game_car),
        .game_obs           (game_obs),
        .game_obs1          (game_obs1),
        .game_obs2          (game_obs2),
        .game_bonus         (game_bonus),
        .game_flags         (game_flags),
        .game_score         (game_score),
        .game_commit_toggle (game_commit_toggle),
        .car_lane           (cdc_car_lane),
        .car_y              (cdc_car_y),
        .obs_lane           (cdc_obs_lane),
        .obs_x              (cdc_obs_x),
        .obs_active         (cdc_obs_active),
        .obs1_lane          (cdc_obs1_lane),
        .obs1_x             (cdc_obs1_x),
        .obs1_active        (cdc_obs1_active),
        .obs2_lane          (cdc_obs2_lane),
        .obs2_x             (cdc_obs2_x),
        .obs2_active        (cdc_obs2_active),
        .bonus_lane         (cdc_bonus_lane),
        .bonus_x            (cdc_bonus_x),
        .bonus_active       (cdc_bonus_active),
        .game_enable        (cdc_game_enable),
        .paused             (cdc_paused),
        .game_over          (cdc_game_over),
        .bg_enable          (cdc_bg_enable),
        .backlight_enable   (cdc_backlight_enable),
        .waiting_start      (cdc_waiting_start),
        .difficulty_level   (cdc_difficulty_level),
        .score              (cdc_score),
        .speed_q8           (cdc_speed_q8),
        .speed_level        (),
        .commit_ack         (),
        .commit_ack_toggle  (commit_ack_toggle)
    );

    wire        bus_ready;
    wire        init_bus_valid;
    wire        init_bus_rs;
    wire [15:0] init_bus_data;
    wire        init_done;
    wire [7:0]  init_step;

    lcd_init_engine #(
        .SIMULATION     (SIMULATION),
        .LCD_CONTROLLER (LCD_CONTROLLER)
    ) u_init(
        .clk       (clk),
        .resetn    (resetn),
        .lcd_rst   (lcd_rst),
        .bus_valid (init_bus_valid),
        .bus_ready (bus_ready),
        .bus_rs    (init_bus_rs),
        .bus_data  (init_bus_data),
        .done      (init_done),
        .active    (),
        .step      (init_step)
    );

    reg [9:0] px_x;
    reg [8:0] px_y;
    reg [9:0] rotated_render_x;
    reg [8:0] rotated_render_y;
    reg [1:0] rotated_row_phase;
    reg [2:0] rotated_col_phase;
    reg       stream_state;
    reg       frame_toggle;
    reg [17:0] bg_scroll_q8;
    reg [3:0]  scroll_rate_phase;

    localparam S_WRITE_RAM = 1'b0;
    localparam S_PIXELS    = 1'b1;

    wire [2:0] rotated_row_phase_sum = {1'b0, rotated_row_phase} + 3'd5;
    wire [3:0] rotated_col_phase_sum = {1'b0, rotated_col_phase} + 4'd3;

    wire [15:0] game_pixel_color;
    wire [15:0] leaderboard_pixel_color;
    wire [15:0] pixel_color = LEADERBOARD_MODE ? leaderboard_pixel_color : game_pixel_color;
    wire [9:0]  bg_scroll = bg_scroll_q8[17:8];
    racing_pixel_renderer u_renderer(
        .x             (rotated_render_x),
        .y             (rotated_render_y),
        .bg_scroll     (bg_scroll),
        .car_lane      (render_car_lane),
        .car_y         (render_car_y),
        .obs_lane      (render_obs_lane),
        .obs_x         (render_obs_x),
        .obs_active    (render_obs_active),
        .obs1_lane     (render_obs1_lane),
        .obs1_x        (render_obs1_x),
        .obs1_active   (render_obs1_active),
        .obs2_lane     (render_obs2_lane),
        .obs2_x        (render_obs2_x),
        .obs2_active   (render_obs2_active),
        .bonus_lane    (render_bonus_lane),
        .bonus_x       (render_bonus_x),
        .bonus_active  (render_bonus_active),
        .game_enable   (render_game_enable),
        .paused        (render_paused),
        .game_over     (render_game_over),
        .waiting_start (render_waiting_start),
        .bg_enable     (render_bg_enable),
        .score         (render_score),
        .speed_q8      (render_speed_q8),
        .difficulty_level(render_difficulty_level),
        .pixel         (game_pixel_color)
    );

    leaderboard_pixel_renderer u_leaderboard_renderer(
        .clk           (clk),
        .resetn        (resetn),
        .x             (rotated_render_x),
        .y             (rotated_render_y),
        .scores_bcd_packed (render_leaderboard_bcd_scores),
        .score_count   (render_leaderboard_count),
        .pixel         (leaderboard_pixel_color)
    );

    wire        stream_valid = init_done;
    wire        stream_rs    = (stream_state == S_PIXELS);
    wire [15:0] stream_data  = (stream_state == S_WRITE_RAM) ? 16'h2C00 : pixel_color;
    wire        stream_fire  = stream_valid & bus_ready;
    wire        last_x       = (px_x == H_RES - 1);
    wire        last_y       = (px_y == V_RES - 1);
    wire [4:0]  scroll_rate_phase_sum = {1'b0, scroll_rate_phase} + 5'd2;
    wire        scroll_rate_carry     = (scroll_rate_phase_sum >= 5'd13);
    wire [3:0]  scroll_rate_phase_next = scroll_rate_carry ?
                                         (scroll_rate_phase_sum - 5'd13) :
                                         scroll_rate_phase_sum[3:0];
    wire [17:0] scroll_step_q8 = {2'b00, pend_speed_q8};
    wire [17:0] frame_scroll_step_q8 = scroll_rate_carry ?
                                       (scroll_step_q8 + scroll_step_q8) :
                                       scroll_step_q8;

    always @(posedge clk or negedge resetn)
    begin
        if (!resetn)
        begin
            pend_car_lane         <= DEFAULT_CAR_LANE;
            pend_car_y            <= 9'd210;
            pend_obs_lane         <= DEFAULT_OBS_LANE;
            pend_obs_x            <= DEFAULT_OBJ_X;
            pend_obs_active       <= 1'b0;
            pend_obs1_lane        <= DEFAULT_OBS_LANE;
            pend_obs1_x           <= DEFAULT_OBJ_X;
            pend_obs1_active      <= 1'b0;
            pend_obs2_lane        <= DEFAULT_OBS_LANE;
            pend_obs2_x           <= DEFAULT_OBJ_X;
            pend_obs2_active      <= 1'b0;
            pend_bonus_lane       <= DEFAULT_BONUS_LANE;
            pend_bonus_x          <= DEFAULT_OBJ_X;
            pend_bonus_active     <= 1'b0;
            pend_game_enable      <= 1'b1;
            pend_paused           <= 1'b0;
            pend_game_over        <= 1'b0;
            pend_bg_enable        <= 1'b1;
            pend_backlight_enable <= 1'b1;
            pend_waiting_start     <= 1'b1;
            pend_difficulty_level  <= 5'd0;
            pend_score            <= 16'd0;
            pend_speed_q8         <= 16'd0;
        end
        else
        begin
            pend_car_lane         <= cdc_car_lane;
            pend_car_y            <= cdc_car_y;
            pend_obs_lane         <= cdc_obs_lane;
            pend_obs_x            <= cdc_obs_x;
            pend_obs_active       <= cdc_obs_active;
            pend_obs1_lane        <= cdc_obs1_lane;
            pend_obs1_x           <= cdc_obs1_x;
            pend_obs1_active      <= cdc_obs1_active;
            pend_obs2_lane        <= cdc_obs2_lane;
            pend_obs2_x           <= cdc_obs2_x;
            pend_obs2_active      <= cdc_obs2_active;
            pend_bonus_lane       <= cdc_bonus_lane;
            pend_bonus_x          <= cdc_bonus_x;
            pend_bonus_active     <= cdc_bonus_active;
            pend_game_enable      <= cdc_game_enable;
            pend_paused           <= cdc_paused;
            pend_game_over        <= cdc_game_over;
            pend_bg_enable        <= cdc_bg_enable;
            pend_backlight_enable <= cdc_backlight_enable;
            pend_waiting_start     <= cdc_waiting_start;
            pend_difficulty_level  <= cdc_difficulty_level;
            pend_score            <= cdc_score;
            pend_speed_q8         <= cdc_speed_q8;
        end
    end

    always @(posedge clk or negedge resetn)
    begin
        if (!resetn)
        begin
            px_x         <= 10'd0;
            px_y         <= 9'd0;
            rotated_render_x <= 10'd0;
            rotated_render_y <= 9'd479;
            rotated_row_phase <= 2'd0;
            rotated_col_phase <= 3'd0;
            stream_state <= S_WRITE_RAM;
            frame_toggle <= 1'b0;
            bg_scroll_q8 <= 18'd0;
            scroll_rate_phase <= 4'd0;
            render_car_lane    <= DEFAULT_CAR_LANE;
            render_car_y       <= 9'd210;
            render_obs_lane    <= DEFAULT_OBS_LANE;
            render_obs_x       <= DEFAULT_OBJ_X;
            render_obs_active  <= 1'b0;
            render_obs1_lane   <= DEFAULT_OBS_LANE;
            render_obs1_x      <= DEFAULT_OBJ_X;
            render_obs1_active <= 1'b0;
            render_obs2_lane   <= DEFAULT_OBS_LANE;
            render_obs2_x      <= DEFAULT_OBJ_X;
            render_obs2_active <= 1'b0;
            render_bonus_lane  <= DEFAULT_BONUS_LANE;
            render_bonus_x     <= DEFAULT_OBJ_X;
            render_bonus_active <= 1'b0;
            render_game_enable <= 1'b1;
            render_paused      <= 1'b0;
            render_game_over   <= 1'b0;
            render_waiting_start <= 1'b1;
            render_difficulty_level <= 5'd0;
            render_bg_enable   <= 1'b1;
            render_score       <= 16'd0;
            render_speed_q8    <= 16'd0;
            render_leaderboard_bcd_scores <= 160'd0;
            render_leaderboard_count  <= 4'd0;
        end
        else if (init_done && stream_fire)
        begin
            if (stream_state == S_WRITE_RAM)
            begin
                px_x         <= 10'd0;
                px_y         <= 9'd0;
                rotated_render_x <= 10'd0;
                rotated_render_y <= 9'd479;
                rotated_row_phase <= 2'd0;
                rotated_col_phase <= 3'd0;
                stream_state <= S_PIXELS;
            end
            else if (last_x && last_y)
            begin
                px_x         <= 10'd0;
                px_y         <= 9'd0;
                rotated_render_x <= 10'd0;
                rotated_render_y <= 9'd479;
                rotated_row_phase <= 2'd0;
                rotated_col_phase <= 3'd0;
                stream_state <= S_WRITE_RAM;
                frame_toggle <= ~frame_toggle;
                render_car_lane    <= pend_car_lane;
                render_car_y       <= pend_car_y;
                render_obs_lane    <= pend_obs_lane;
                render_obs_x       <= pend_obs_x;
                render_obs_active  <= pend_obs_active;
                render_obs1_lane   <= pend_obs1_lane;
                render_obs1_x      <= pend_obs1_x;
                render_obs1_active <= pend_obs1_active;
                render_obs2_lane   <= pend_obs2_lane;
                render_obs2_x      <= pend_obs2_x;
                render_obs2_active <= pend_obs2_active;
                render_bonus_lane  <= pend_bonus_lane;
                render_bonus_x     <= pend_bonus_x;
                render_bonus_active <= pend_bonus_active;
                render_game_enable <= pend_game_enable;
                render_paused      <= pend_paused;
                render_game_over   <= pend_game_over;
                render_waiting_start <= pend_waiting_start;
                render_difficulty_level <= pend_difficulty_level;
                render_bg_enable   <= pend_bg_enable;
                render_score       <= pend_score;
                render_speed_q8    <= pend_speed_q8;
                render_leaderboard_bcd_scores <= leaderboard_bcd_scores;
                render_leaderboard_count  <= leaderboard_count;
                if (pend_game_enable && !pend_paused && !pend_game_over && !pend_waiting_start)
                begin
                    bg_scroll_q8     <= bg_scroll_q8 + frame_scroll_step_q8;
                    scroll_rate_phase <= scroll_rate_phase_next;
                end
            end
            else if (last_x)
            begin
                px_x <= 10'd0;
                px_y <= px_y + 9'd1;
                rotated_render_y <= 9'd479;
                rotated_col_phase <= 3'd0;
                if (rotated_row_phase_sum >= 3'd6)
                begin
                    rotated_render_x <= rotated_render_x + 10'd2;
                    rotated_row_phase <= rotated_row_phase_sum - 3'd6;
                end
                else
                begin
                    rotated_render_x <= rotated_render_x + 10'd1;
                    rotated_row_phase <= rotated_row_phase_sum - 3'd3;
                end
            end
            else
            begin
                px_x <= px_x + 10'd1;
                if (rotated_col_phase_sum >= 4'd5)
                begin
                    rotated_render_y <= rotated_render_y - 9'd1;
                    rotated_col_phase <= rotated_col_phase_sum - 4'd5;
                end
                else
                begin
                    rotated_col_phase <= rotated_col_phase_sum[2:0];
                end
            end
        end
    end

    wire        bus_valid = init_done ? stream_valid : init_bus_valid;
    wire        bus_rs    = init_done ? stream_rs    : init_bus_rs;
    wire [15:0] bus_data  = init_done ? stream_data  : init_bus_data;
    wire [15:0] lcd_db;
    wire        controller_status = (LCD_CONTROLLER != 0);

    lcd_8080_write_master u_write_master(
        .clk        (clk),
        .resetn     (resetn),
        .wr_valid   (bus_valid),
        .wr_ready   (bus_ready),
        .wr_rs      (bus_rs),
        .wr_data    (bus_data),
        .write_fire (),
        .lcd_db     (lcd_db),
        .lcd_wr     (lcd_wr),
        .lcd_rs     (lcd_rs)
    );

    assign lcd_data_io = lcd_db;
    assign lcd_cs      = 1'b0;
    assign lcd_rd      = 1'b1;
    assign lcd_bl_ctr  = pend_backlight_enable;

    assign ct_int  = 1'bz;
    assign ct_sda  = 1'bz;
    assign ct_scl  = 1'b1;
    assign ct_rstn = 1'b1;

    assign lcd_status = {8'd0, px_y[7:0], init_step, 4'd0,
                         controller_status, commit_ack_toggle,
                         frame_toggle, init_done};

endmodule

`default_nettype wire
