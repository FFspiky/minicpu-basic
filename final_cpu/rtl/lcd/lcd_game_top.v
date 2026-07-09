`timescale 1ns / 1ps
`default_nettype none

module lcd_game_top #(
    parameter SIMULATION = 1'b0,
    parameter integer LCD_CONTROLLER = 0,
    parameter integer H_RES = 800,
    parameter integer V_RES = 480
)(
    input  wire        clk,
    input  wire        resetn,

    input  wire [31:0] game_car,
    input  wire [31:0] game_obs,
    input  wire [31:0] game_bonus,
    input  wire [31:0] game_flags,
    input  wire [31:0] game_score,
    input  wire        game_commit_toggle,
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

    wire [1:0]  car_lane;
    wire [1:0]  obs_lane;
    wire [9:0]  obs_x;
    wire        obs_active;
    wire [1:0]  bonus_lane;
    wire [9:0]  bonus_x;
    wire        bonus_active;
    wire        game_enable;
    wire        paused;
    wire        game_over;
    wire        bg_enable;
    wire        backlight_enable;
    wire [15:0] score;
    wire [15:0] speed_level;
    wire        commit_ack_toggle;

    game_state_cdc u_game_state_cdc(
        .clk                (clk),
        .resetn             (resetn),
        .game_car           (game_car),
        .game_obs           (game_obs),
        .game_bonus         (game_bonus),
        .game_flags         (game_flags),
        .game_score         (game_score),
        .game_commit_toggle (game_commit_toggle),
        .car_lane           (car_lane),
        .obs_lane           (obs_lane),
        .obs_x              (obs_x),
        .obs_active         (obs_active),
        .bonus_lane         (bonus_lane),
        .bonus_x            (bonus_x),
        .bonus_active       (bonus_active),
        .game_enable        (game_enable),
        .paused             (paused),
        .game_over          (game_over),
        .bg_enable          (bg_enable),
        .backlight_enable   (backlight_enable),
        .score              (score),
        .speed_level        (speed_level),
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
    reg       stream_state;
    reg       frame_toggle;
    reg [9:0] bg_scroll;

    localparam S_WRITE_RAM = 1'b0;
    localparam S_PIXELS    = 1'b1;

    wire [15:0] pixel_color;
    racing_pixel_renderer u_renderer(
        .x             (px_x),
        .y             (px_y),
        .bg_scroll     (bg_scroll),
        .car_lane      (car_lane),
        .obs_lane      (obs_lane),
        .obs_x         (obs_x),
        .obs_active    (obs_active),
        .bonus_lane    (bonus_lane),
        .bonus_x       (bonus_x),
        .bonus_active  (bonus_active),
        .game_enable   (game_enable),
        .paused        (paused),
        .game_over     (game_over),
        .bg_enable     (bg_enable),
        .score         (score),
        .speed_level   (speed_level),
        .pixel         (pixel_color)
    );

    wire        stream_valid = init_done;
    wire        stream_rs    = (stream_state == S_PIXELS);
    wire [15:0] stream_data  = (stream_state == S_WRITE_RAM) ? 16'h2C00 : pixel_color;
    wire        stream_fire  = stream_valid & bus_ready;
    wire        last_x       = (px_x == H_RES - 1);
    wire        last_y       = (px_y == V_RES - 1);

    always @(posedge clk or negedge resetn)
    begin
        if (!resetn)
        begin
            px_x         <= 10'd0;
            px_y         <= 9'd0;
            stream_state <= S_WRITE_RAM;
            frame_toggle <= 1'b0;
            bg_scroll    <= 10'd0;
        end
        else if (init_done && stream_fire)
        begin
            if (stream_state == S_WRITE_RAM)
            begin
                px_x         <= 10'd0;
                px_y         <= 9'd0;
                stream_state <= S_PIXELS;
            end
            else if (last_x && last_y)
            begin
                px_x         <= 10'd0;
                px_y         <= 9'd0;
                stream_state <= S_WRITE_RAM;
                frame_toggle <= ~frame_toggle;
                if (game_enable && !paused && !game_over)
                begin
                    bg_scroll <= bg_scroll + 10'd4;
                end
            end
            else if (last_x)
            begin
                px_x <= 10'd0;
                px_y <= px_y + 9'd1;
            end
            else
            begin
                px_x <= px_x + 10'd1;
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
    assign lcd_bl_ctr  = backlight_enable;

    assign ct_int  = 1'bz;
    assign ct_sda  = 1'bz;
    assign ct_scl  = 1'b1;
    assign ct_rstn = 1'b1;

    assign lcd_status = {8'd0, px_y[7:0], init_step, 4'd0,
                         controller_status, commit_ack_toggle,
                         frame_toggle, init_done};

endmodule

`default_nettype wire
