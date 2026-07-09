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
    wire        game_over_text;

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

    function letter_pixel;
        input [3:0] ch;
        input [9:0] lx;
        input [8:0] ly;
        begin
            case (ch)
                4'd0: letter_pixel = (ly < 9'd6) || (ly >= 9'd42) || (lx < 10'd6) ||
                                      ((lx >= 10'd22) && (ly >= 9'd24)) ||
                                      ((ly >= 9'd22 && ly < 9'd28) && lx >= 10'd14); // G
                4'd1: letter_pixel = (ly < 9'd6) || (ly >= 9'd22 && ly < 9'd28) ||
                                      (lx < 10'd6) || (lx >= 10'd22); // A
                4'd2: letter_pixel = (lx < 10'd6) || (lx >= 10'd22) ||
                                      ((ly < 9'd24) &&
                                       ((lx >= 10'd6 && lx < 10'd10) || (lx >= 10'd18 && lx < 10'd22))); // M
                4'd3: letter_pixel = (lx < 10'd6) || (ly < 9'd6) ||
                                      (ly >= 9'd22 && ly < 9'd28) || (ly >= 9'd42); // E
                4'd4: letter_pixel = (lx < 10'd6) || (lx >= 10'd22) ||
                                      (ly < 9'd6) || (ly >= 9'd42); // O
                4'd5: letter_pixel = ((ly < 9'd34) && ((lx < 10'd6) || (lx >= 10'd22))) ||
                                      ((ly >= 9'd34) && lx >= 10'd10 && lx < 10'd18); // V
                4'd6: letter_pixel = (lx < 10'd6) || (ly < 9'd6) ||
                                      (ly >= 9'd22 && ly < 9'd28) ||
                                      ((lx >= 10'd22) && ly < 9'd28) ||
                                      ((ly >= 9'd28) && (lx >= ly - 9'd8) && (lx < ly)); // R
                default: letter_pixel = 1'b0;
            endcase
        end
    endfunction

    function game_over_letter;
        input [9:0] tx;
        input [8:0] ty;
        begin
            game_over_letter =
                ((tx >= 10'd211 && tx < 10'd239) && letter_pixel(4'd0, tx - 10'd211, ty - 9'd216)) ||
                ((tx >= 10'd253 && tx < 10'd281) && letter_pixel(4'd1, tx - 10'd253, ty - 9'd216)) ||
                ((tx >= 10'd295 && tx < 10'd323) && letter_pixel(4'd2, tx - 10'd295, ty - 9'd216)) ||
                ((tx >= 10'd337 && tx < 10'd365) && letter_pixel(4'd3, tx - 10'd337, ty - 9'd216)) ||
                ((tx >= 10'd421 && tx < 10'd449) && letter_pixel(4'd4, tx - 10'd421, ty - 9'd216)) ||
                ((tx >= 10'd463 && tx < 10'd491) && letter_pixel(4'd5, tx - 10'd463, ty - 9'd216)) ||
                ((tx >= 10'd505 && tx < 10'd533) && letter_pixel(4'd3, tx - 10'd505, ty - 9'd216)) ||
                ((tx >= 10'd547 && tx < 10'd575) && letter_pixel(4'd6, tx - 10'd547, ty - 9'd216));
        end
    endfunction

    assign game_over_text = game_over && y >= 9'd216 && y < 9'd264 &&
                            x >= 10'd211 && x < 10'd575 && game_over_letter(x, y);

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
                    if (game_over_text)
                    begin
                        pixel = C_RED;
                    end
                end
            end
        end
    end

endmodule

`default_nettype wire
