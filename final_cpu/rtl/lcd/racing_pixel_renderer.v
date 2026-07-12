`timescale 1ns / 1ps
`default_nettype none

module racing_pixel_renderer(
    input  wire [9:0]  x,
    input  wire [8:0]  y,
    input  wire [9:0]  bg_scroll,

    input  wire [1:0]  car_lane,
    input  wire [8:0]  car_y,
    input  wire [1:0]  obs_lane,
    input  wire [9:0]  obs_x,
    input  wire        obs_active,
    input  wire [1:0]  obs1_lane,
    input  wire [9:0]  obs1_x,
    input  wire        obs1_active,
    input  wire [1:0]  obs2_lane,
    input  wire [9:0]  obs2_x,
    input  wire        obs2_active,
    input  wire [1:0]  bonus_lane,
    input  wire [9:0]  bonus_x,
    input  wire        bonus_active,
    input  wire        game_enable,
    input  wire        paused,
    input  wire        game_over,
    input  wire        waiting_start,
    input  wire        bg_enable,
    input  wire [15:0] score,
    input  wire [15:0] speed_q8,
    input  wire [4:0]  difficulty_level,

    output reg  [15:0] pixel
);

    localparam [15:0] C_BLACK      = 16'h0000;
    localparam [15:0] C_WHITE      = 16'hFFFF;
    localparam [15:0] C_ROAD_DARK  = 16'h18E3;
    localparam [15:0] C_ROAD_LITE  = 16'h2945;
    localparam [15:0] C_GRASS      = 16'h05C0;
    localparam [15:0] C_GRASS_DARK = 16'h03A0;
    localparam [15:0] C_RED        = 16'hF800;
    localparam [15:0] C_GREEN      = 16'h07E0;
    localparam [15:0] C_BLUE       = 16'h001F;
    localparam [15:0] C_YELLOW     = 16'hFFE0;
    localparam [15:0] C_CAR        = 16'hFCA0;
    localparam [15:0] C_WINDOW     = 16'h07FF;
    localparam [15:0] C_PANEL      = 16'h2104;

    localparam [1:0] TEXT_PRESS = 2'd0;
    localparam [1:0] TEXT_PAUSE = 2'd1;
    localparam [1:0] TEXT_OVER  = 2'd2;

    wire [10:0] x_ext = {1'b0, x};
    wire [10:0] obs_x0 = {1'b0, obs_x};
    wire [10:0] obs_x1 = {1'b0, obs_x} + 11'd44;
    wire [10:0] obs1_x0 = {1'b0, obs1_x};
    wire [10:0] obs1_x1 = {1'b0, obs1_x} + 11'd44;
    wire [10:0] obs2_x0 = {1'b0, obs2_x};
    wire [10:0] obs2_x1 = {1'b0, obs2_x} + 11'd44;
    wire [10:0] bonus_x0 = {1'b0, bonus_x};
    wire [10:0] bonus_x1 = {1'b0, bonus_x} + 11'd36;
    wire [9:0] road_phase = x + bg_scroll;

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

    function [34:0] glyph_bitmap;
        input [7:0] ch;
        begin
            case (ch)
                8'h41: glyph_bitmap = {5'b01110,5'b10001,5'b10001,5'b11111,5'b10001,5'b10001,5'b10001}; // A
                8'h45: glyph_bitmap = {5'b11111,5'b10000,5'b10000,5'b11110,5'b10000,5'b10000,5'b11111}; // E
                8'h47: glyph_bitmap = {5'b01110,5'b10001,5'b10000,5'b10111,5'b10001,5'b10001,5'b01110}; // G
                8'h4B: glyph_bitmap = {5'b10001,5'b10010,5'b10100,5'b11000,5'b10100,5'b10010,5'b10001}; // K
                8'h4D: glyph_bitmap = {5'b10001,5'b11011,5'b10101,5'b10101,5'b10001,5'b10001,5'b10001}; // M
                8'h4F: glyph_bitmap = {5'b01110,5'b10001,5'b10001,5'b10001,5'b10001,5'b10001,5'b01110}; // O
                8'h50: glyph_bitmap = {5'b11110,5'b10001,5'b10001,5'b11110,5'b10000,5'b10000,5'b10000}; // P
                8'h52: glyph_bitmap = {5'b11110,5'b10001,5'b10001,5'b11110,5'b10100,5'b10010,5'b10001}; // R
                8'h53: glyph_bitmap = {5'b01111,5'b10000,5'b10000,5'b01110,5'b00001,5'b00001,5'b11110}; // S
                8'h55: glyph_bitmap = {5'b10001,5'b10001,5'b10001,5'b10001,5'b10001,5'b10001,5'b01110}; // U
                8'h56: glyph_bitmap = {5'b10001,5'b10001,5'b10001,5'b10001,5'b10001,5'b01010,5'b00100}; // V
                8'h59: glyph_bitmap = {5'b10001,5'b01010,5'b00100,5'b00100,5'b00100,5'b00100,5'b00100}; // Y
                default: glyph_bitmap = 35'd0;
            endcase
        end
    endfunction

    function [7:0] message_char;
        input [1:0] mode;
        input [3:0] index;
        begin
            message_char = 8'h20;
            case (mode)
                TEXT_PRESS:
                    case (index)
                        4'd0: message_char = 8'h50;
                        4'd1: message_char = 8'h52;
                        4'd2: message_char = 8'h45;
                        4'd3: message_char = 8'h53;
                        4'd4: message_char = 8'h53;
                        4'd6: message_char = 8'h4B;
                        4'd7: message_char = 8'h45;
                        4'd8: message_char = 8'h59;
                        default: message_char = 8'h20;
                    endcase
                TEXT_PAUSE:
                    case (index)
                        4'd0: message_char = 8'h50;
                        4'd1: message_char = 8'h41;
                        4'd2: message_char = 8'h55;
                        4'd3: message_char = 8'h53;
                        4'd4: message_char = 8'h45;
                        default: message_char = 8'h20;
                    endcase
                default:
                    case (index)
                        4'd0: message_char = 8'h47;
                        4'd1: message_char = 8'h41;
                        4'd2: message_char = 8'h4D;
                        4'd3: message_char = 8'h45;
                        4'd5: message_char = 8'h4F;
                        4'd6: message_char = 8'h56;
                        4'd7: message_char = 8'h45;
                        4'd8: message_char = 8'h52;
                        default: message_char = 8'h20;
                    endcase
            endcase
        end
    endfunction

    function glyph_pixel;
        input [7:0] ch;
        input [2:0] col;
        input [2:0] row;
        reg [34:0] bitmap;
        integer bit_index;
        begin
            bitmap = glyph_bitmap(ch);
            bit_index = 34 - row * 5 - col;
            if (col < 3'd5 && row < 3'd7)
                glyph_pixel = bitmap[bit_index];
            else
                glyph_pixel = 1'b0;
        end
    endfunction

    wire [8:0] obs_y0 = lane_top(obs_lane) + 9'd8;
    wire [8:0] obs1_y0 = lane_top(obs1_lane) + 9'd8;
    wire [8:0] obs2_y0 = lane_top(obs2_lane) + 9'd8;
    wire [8:0] bonus_y0 = lane_top(bonus_lane) + 9'd12;

    reg [1:0] text_mode;
    reg [8:0] text_start_y;
    reg [3:0] text_length;
    reg [15:0] text_color;
    reg text_active;
    reg text_pixel;
    reg [8:0] text_dy;
    reg [3:0] text_slot;
    reg [4:0] text_local_y;
    reg [2:0] glyph_col;
    reg [2:0] glyph_row;
    reg [7:0] glyph_char;

    always @(*)
    begin
        text_mode = TEXT_PRESS;
        text_start_y = 9'd96;
        text_length = 4'd9;
        text_color = C_GREEN;
        text_active = 1'b0;

        if (game_over)
        begin
            text_mode = TEXT_OVER;
            text_start_y = 9'd96;
            text_length = 4'd9;
            text_color = C_RED;
            text_active = 1'b1;
        end
        else if (paused)
        begin
            text_mode = TEXT_PAUSE;
            text_start_y = 9'd160;
            text_length = 4'd5;
            text_color = C_YELLOW;
            text_active = 1'b1;
        end
        else if (waiting_start)
        begin
            text_mode = TEXT_PRESS;
            text_start_y = 9'd96;
            text_length = 4'd9;
            text_color = C_GREEN;
            text_active = 1'b1;
        end

        text_pixel = 1'b0;
        text_dy = y - text_start_y;
        text_slot = text_dy[8:5];
        text_local_y = text_dy[4:0];
        glyph_col = text_local_y[4:2];
        glyph_row = 3'd6 - ((x - 10'd386) >> 2);
        glyph_char = message_char(text_mode, text_slot);

        if (text_active && x >= 10'd386 && x < 10'd414 &&
            y >= text_start_y && text_slot < text_length &&
            text_local_y < 5'd20)
            text_pixel = glyph_pixel(glyph_char, glyph_col, glyph_row);
    end

    always @(*)
    begin
        pixel = C_BLACK;

        if (game_enable)
        begin
            if (!bg_enable)
                pixel = C_BLACK;
            else if (x < 10'd24 || x > 10'd775)
                pixel = C_GRASS;
            else
                pixel = C_ROAD_DARK;

            if ((y >= 9'd158 && y <= 9'd162) ||
                (y >= 9'd318 && y <= 9'd322))
            begin
                // Move only the dashed lane markers.  The road itself stays
                // stable, avoiding full-screen brightness pulses at high speed.
                pixel = (road_phase[6:5] == 2'b00) ? C_WHITE : C_ROAD_DARK;
            end

            if (x >= 10'd100 && x <= 10'd180 &&
                y >= car_y && y <= car_y + 9'd60)
            begin
                if (((x >= 10'd100 && x <= 10'd106) ||
                     (x >= 10'd174 && x <= 10'd180)) &&
                    y >= car_y + 9'd8 && y <= car_y + 9'd52)
                    pixel = C_BLACK;
                else if (x >= 10'd148 && x <= 10'd172 &&
                         y >= car_y + 9'd20 && y <= car_y + 9'd40)
                    pixel = C_WINDOW;
                else if (x >= 10'd106 && x <= 10'd174)
                    pixel = C_CAR;
            end

            if (obs_active && x_ext >= obs_x0 && x_ext <= obs_x1 &&
                y >= obs_y0 && y <= obs_y0 + 9'd44)
                pixel = (x_ext == obs_x0 || x_ext == obs_x1 ||
                         y == obs_y0 || y == obs_y0 + 9'd44) ? C_WHITE : C_BLUE;

            if (obs1_active && x_ext >= obs1_x0 && x_ext <= obs1_x1 &&
                y >= obs1_y0 && y <= obs1_y0 + 9'd44)
                pixel = (x_ext == obs1_x0 || x_ext == obs1_x1 ||
                         y == obs1_y0 || y == obs1_y0 + 9'd44) ? C_WHITE : C_BLUE;

            if (obs2_active && x_ext >= obs2_x0 && x_ext <= obs2_x1 &&
                y >= obs2_y0 && y <= obs2_y0 + 9'd44)
                pixel = (x_ext == obs2_x0 || x_ext == obs2_x1 ||
                         y == obs2_y0 || y == obs2_y0 + 9'd44) ? C_WHITE : C_BLUE;

            if (bonus_active && x_ext >= bonus_x0 && x_ext <= bonus_x1 &&
                y >= bonus_y0 && y <= bonus_y0 + 9'd36 &&
                (x_ext - bonus_x0) + (y - bonus_y0) > 11'd12 &&
                (x_ext - bonus_x0) + (y - bonus_y0) < 11'd60)
                pixel = C_YELLOW;

            if (text_active && x >= 10'd350 && x <= 10'd450 &&
                y >= 9'd80 && y <= 9'd400)
            begin
                if (x == 10'd350 || x == 10'd450 || y == 9'd80 || y == 9'd400)
                    pixel = C_WHITE;
                else
                    pixel = C_PANEL;
            end

            if (text_pixel)
                pixel = text_color;
        end
    end

    wire unused_ok = &{1'b0, car_lane, score[0], speed_q8[0], difficulty_level[0]};

endmodule

`default_nettype wire
