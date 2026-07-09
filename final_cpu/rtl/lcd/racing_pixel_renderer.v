`timescale 1ns / 1ps
`default_nettype none

module racing_pixel_renderer(
    input  wire [9:0]  x,
    input  wire [8:0]  y,
    input  wire [9:0]  bg_scroll,

    input  wire [1:0]  car_lane,
    input  wire [1:0]  obs_lane,
    input  wire [9:0]  obs_x,
    input  wire        obs_active,
    input  wire [1:0]  bonus_lane,
    input  wire [9:0]  bonus_x,
    input  wire        bonus_active,
    input  wire        game_enable,
    input  wire        paused,
    input  wire        game_over,
    input  wire        bg_enable,
    input  wire [15:0] score,
    input  wire [15:0] speed_level,

    output reg  [15:0] pixel
);

    localparam [15:0] C_BLACK      = 16'h0000;
    localparam [15:0] C_WHITE      = 16'hFFFF;
    localparam [15:0] C_ROAD_DARK  = 16'h18E3;
    localparam [15:0] C_ROAD_LITE  = 16'h2945;
    localparam [15:0] C_GRASS      = 16'h05C0;
    localparam [15:0] C_GRASS_DARK = 16'h03A0;
    localparam [15:0] C_RED        = 16'hF800;
    localparam [15:0] C_BLUE       = 16'h001F;
    localparam [15:0] C_YELLOW     = 16'hFFE0;
    localparam [15:0] C_CAR        = 16'hFCA0;
    localparam [15:0] C_WINDOW     = 16'h07FF;
    localparam [15:0] C_PANEL      = 16'h2104;

    wire [10:0] x_ext       = {1'b0, x};
    wire [10:0] obs_x0      = {1'b0, obs_x};
    wire [10:0] obs_x1      = {1'b0, obs_x} + 11'd44;
    wire [10:0] bonus_x0    = {1'b0, bonus_x};
    wire [10:0] bonus_x1    = {1'b0, bonus_x} + 11'd36;
    wire [9:0]  road_scroll = x + bg_scroll + score[9:0] + {speed_level[4:0], 5'b0};

    reg [8:0] car_y0;
    reg [8:0] obs_y0;
    reg [8:0] bonus_y0;

    function [8:0] lane_top;
        input [1:0] lane;
        begin
            case (lane)
                2'd0: lane_top = 9'd50;
                2'd1: lane_top = 9'd210;
                default: lane_top = 9'd370;
            endcase
        end
    endfunction

    always @(*)
    begin
        car_y0   = lane_top(car_lane);
        obs_y0   = lane_top(obs_lane) + 9'd8;
        bonus_y0 = lane_top(bonus_lane) + 9'd12;

        pixel = C_BLACK;

        if (game_enable)
        begin
            if (!bg_enable)
            begin
                pixel = C_BLACK;
            end
            else if (x < 10'd24 || x > 10'd775)
            begin
                pixel = road_scroll[5] ? C_GRASS : C_GRASS_DARK;
            end
            else
            begin
                pixel = road_scroll[7] ? C_ROAD_DARK : C_ROAD_LITE;
            end

            if ((y >= 9'd158 && y <= 9'd162) || (y >= 9'd318 && y <= 9'd322))
            begin
                if (road_scroll[6])
                begin
                    pixel = C_WHITE;
                end
            end

            if (x >= 10'd100 && x <= 10'd180 && y >= car_y0 && y <= car_y0 + 9'd60)
            begin
                if (((x >= 10'd100 && x <= 10'd106) || (x >= 10'd174 && x <= 10'd180)) &&
                    y >= car_y0 + 9'd8 && y <= car_y0 + 9'd52)
                begin
                    pixel = C_BLACK;
                end
                else if (x >= 10'd148 && x <= 10'd172 && y >= car_y0 + 9'd20 && y <= car_y0 + 9'd40)
                begin
                    pixel = C_WINDOW;
                end
                else if (x >= 10'd106 && x <= 10'd174)
                begin
                    pixel = C_CAR;
                end
            end

            if (obs_active && x_ext >= obs_x0 && x_ext <= obs_x1 &&
                y >= obs_y0 && y <= obs_y0 + 9'd44)
            begin
                if (x_ext == obs_x0 || x_ext == obs_x1 || y == obs_y0 || y == obs_y0 + 9'd44)
                begin
                    pixel = C_WHITE;
                end
                else
                begin
                    pixel = C_BLUE;
                end
            end

            if (bonus_active && x_ext >= bonus_x0 && x_ext <= bonus_x1 &&
                y >= bonus_y0 && y <= bonus_y0 + 9'd36)
            begin
                if ((x_ext - bonus_x0) + (y - bonus_y0) > 11'd12 &&
                    (x_ext - bonus_x0) + (y - bonus_y0) < 11'd60)
                begin
                    pixel = C_YELLOW;
                end
            end

            if (paused || game_over)
            begin
                if (x >= 10'd200 && x <= 10'd600 && y >= 9'd160 && y <= 9'd320)
                begin
                    if (x == 10'd200 || x == 10'd600 || y == 9'd160 || y == 9'd320)
                    begin
                        pixel = C_WHITE;
                    end
                    else
                    begin
                        pixel = C_PANEL;
                    end
                end

                if (paused && !game_over)
                begin
                    if ((x >= 10'd330 && x <= 10'd370 && y >= 9'd200 && y <= 9'd280) ||
                        (x >= 10'd430 && x <= 10'd470 && y >= 9'd200 && y <= 9'd280))
                    begin
                        pixel = C_YELLOW;
                    end
                end

                if (game_over)
                begin
                    if ((x >= 10'd300 && x <= 10'd500 && y >= 9'd218 && y <= 9'd262) ||
                        (x >= 10'd378 && x <= 10'd422 && y >= 9'd180 && y <= 9'd300))
                    begin
                        pixel = C_RED;
                    end
                end
            end
        end
    end

endmodule

`default_nettype wire
