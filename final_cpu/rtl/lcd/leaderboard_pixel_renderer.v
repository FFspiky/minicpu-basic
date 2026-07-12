`timescale 1ns / 1ps
`default_nettype none

module leaderboard_pixel_renderer(
    input  wire         clk,
    input  wire         resetn,
    input  wire [9:0]   x,
    input  wire [8:0]   y,
    input  wire [159:0] scores_bcd_packed,
    input  wire [3:0]   score_count,
    output reg  [15:0]  pixel
);

    localparam [15:0] C_BLACK  = 16'h0000;
    localparam [15:0] C_WHITE  = 16'hFFFF;
    localparam [15:0] C_GOLD   = 16'hFEC0;
    localparam [15:0] C_CYAN   = 16'h07FF;
    localparam [15:0] C_PANEL  = 16'h1082;
    localparam [15:0] C_BORDER = 16'h4A69;

    reg         dec_title_active;
    reg         dec_row_active;
    reg  [3:0]  dec_char_index;
    reg  [2:0]  dec_row_index;
    reg  [5:0]  dec_cell_x;
    reg  [5:0]  dec_cell_y;
    reg  [15:0] dec_base_pixel;

    reg         s1_title_active;
    reg         s1_row_active;
    reg  [3:0]  s1_char_index;
    reg  [2:0]  s1_row_index;
    reg  [5:0]  s1_cell_x;
    reg  [5:0]  s1_cell_y;
    reg  [15:0] s1_base_pixel;

    reg  [19:0] selected_score;
    reg  [7:0]  selected_char;
    reg  [7:0]  s2_glyph_char;
    reg  [2:0]  s2_glyph_col;
    reg  [2:0]  s2_glyph_row;
    reg         s2_glyph_window;
    reg         s2_title_active;
    reg  [15:0] s2_base_pixel;

    reg  [4:0]  s3_glyph_line;
    reg  [2:0]  s3_glyph_col;
    reg         s3_glyph_window;
    reg         s3_title_active;
    reg  [15:0] s3_base_pixel;
    reg         s3_glyph_on;

    function [7:0] title_char;
        input [3:0] index;
        begin
            case (index)
                4'd0:  title_char = "L";
                4'd1:  title_char = "E";
                4'd2:  title_char = "A";
                4'd3:  title_char = "D";
                4'd4:  title_char = "E";
                4'd5:  title_char = "R";
                4'd6:  title_char = "B";
                4'd7:  title_char = "O";
                4'd8:  title_char = "A";
                4'd9:  title_char = "R";
                4'd10: title_char = "D";
                default: title_char = " ";
            endcase
        end
    endfunction

    function [7:0] digit_char;
        input [3:0] digit;
        begin
            digit_char = (digit <= 4'd9) ? (8'h30 + digit) : " ";
        end
    endfunction

    function [4:0] font_row;
        input [7:0] ch;
        input [2:0] row;
        begin
            font_row = 5'b00000;
            case (ch)
                "A": case (row)
                    0: font_row=5'b01110; 1: font_row=5'b10001; 2: font_row=5'b10001;
                    3: font_row=5'b11111; 4: font_row=5'b10001; 5: font_row=5'b10001;
                    6: font_row=5'b10001; default: font_row=0; endcase
                "B": case (row)
                    0: font_row=5'b11110; 1: font_row=5'b10001; 2: font_row=5'b10001;
                    3: font_row=5'b11110; 4: font_row=5'b10001; 5: font_row=5'b10001;
                    6: font_row=5'b11110; default: font_row=0; endcase
                "D": case (row)
                    0: font_row=5'b11110; 1: font_row=5'b10001; 2: font_row=5'b10001;
                    3: font_row=5'b10001; 4: font_row=5'b10001; 5: font_row=5'b10001;
                    6: font_row=5'b11110; default: font_row=0; endcase
                "E": case (row)
                    0: font_row=5'b11111; 1: font_row=5'b10000; 2: font_row=5'b10000;
                    3: font_row=5'b11110; 4: font_row=5'b10000; 5: font_row=5'b10000;
                    6: font_row=5'b11111; default: font_row=0; endcase
                "L": case (row)
                    0,1,2,3,4,5: font_row=5'b10000; 6: font_row=5'b11111;
                    default: font_row=0; endcase
                "O": case (row)
                    0: font_row=5'b01110; 1,2,3,4,5: font_row=5'b10001;
                    6: font_row=5'b01110; default: font_row=0; endcase
                "R": case (row)
                    0: font_row=5'b11110; 1: font_row=5'b10001; 2: font_row=5'b10001;
                    3: font_row=5'b11110; 4: font_row=5'b10100; 5: font_row=5'b10010;
                    6: font_row=5'b10001; default: font_row=0; endcase
                "0": case (row)
                    0: font_row=5'b01110; 1,2,3,4,5: font_row=5'b10001;
                    6: font_row=5'b01110; default: font_row=0; endcase
                "1": case (row)
                    0: font_row=5'b00100; 1: font_row=5'b01100; 2,3,4,5: font_row=5'b00100;
                    6: font_row=5'b01110; default: font_row=0; endcase
                "2": case (row)
                    0: font_row=5'b01110; 1: font_row=5'b10001; 2: font_row=5'b00001;
                    3: font_row=5'b00010; 4: font_row=5'b00100; 5: font_row=5'b01000;
                    6: font_row=5'b11111; default: font_row=0; endcase
                "3": case (row)
                    0: font_row=5'b11110; 1: font_row=5'b00001; 2: font_row=5'b00001;
                    3: font_row=5'b01110; 4: font_row=5'b00001; 5: font_row=5'b00001;
                    6: font_row=5'b11110; default: font_row=0; endcase
                "4": case (row)
                    0: font_row=5'b00010; 1: font_row=5'b00110; 2: font_row=5'b01010;
                    3: font_row=5'b10010; 4: font_row=5'b11111; 5: font_row=5'b00010;
                    6: font_row=5'b00010; default: font_row=0; endcase
                "5": case (row)
                    0: font_row=5'b11111; 1: font_row=5'b10000; 2: font_row=5'b10000;
                    3: font_row=5'b11110; 4: font_row=5'b00001; 5: font_row=5'b00001;
                    6: font_row=5'b11110; default: font_row=0; endcase
                "6": case (row)
                    0: font_row=5'b01110; 1: font_row=5'b10000; 2: font_row=5'b10000;
                    3: font_row=5'b11110; 4: font_row=5'b10001; 5: font_row=5'b10001;
                    6: font_row=5'b01110; default: font_row=0; endcase
                "7": case (row)
                    0: font_row=5'b11111; 1: font_row=5'b00001; 2: font_row=5'b00010;
                    3: font_row=5'b00100; 4: font_row=5'b01000; 5: font_row=5'b01000;
                    6: font_row=5'b01000; default: font_row=0; endcase
                "8": case (row)
                    0: font_row=5'b01110; 1: font_row=5'b10001; 2: font_row=5'b10001;
                    3: font_row=5'b01110; 4: font_row=5'b10001; 5: font_row=5'b10001;
                    6: font_row=5'b01110; default: font_row=0; endcase
                "9": case (row)
                    0: font_row=5'b01110; 1: font_row=5'b10001; 2: font_row=5'b10001;
                    3: font_row=5'b01111; 4: font_row=5'b00001; 5: font_row=5'b00001;
                    6: font_row=5'b01110; default: font_row=0; endcase
                ".": case (row) 6: font_row=5'b00100; default: font_row=0; endcase
                "-": case (row) 3: font_row=5'b01110; default: font_row=0; endcase
                default: font_row=5'b00000;
            endcase
        end
    endfunction

    always @(*) begin
        dec_title_active = 1'b0;
        dec_row_active = 1'b0;
        dec_row_index = 3'd0;
        dec_char_index = 4'd0;
        dec_cell_x = 6'd0;
        dec_cell_y = 6'd0;

        if (x >= 10'd224 && x < 10'd576 && y >= 9'd40 && y < 9'd68) begin
            dec_title_active = 1'b1;
            dec_char_index = (x - 10'd224) >> 5;
            dec_cell_x = (x - 10'd224) & 10'h01f;
            dec_cell_y = y - 9'd40;
        end

        if (x >= 10'd272 && x < 10'd528) begin
            if      (y >= 9'd96  && y < 9'd124) begin dec_row_active=1'b1; dec_row_index=3'd0; dec_cell_y=y-9'd96;  end
            else if (y >= 9'd140 && y < 9'd168) begin dec_row_active=1'b1; dec_row_index=3'd1; dec_cell_y=y-9'd140; end
            else if (y >= 9'd184 && y < 9'd212) begin dec_row_active=1'b1; dec_row_index=3'd2; dec_cell_y=y-9'd184; end
            else if (y >= 9'd228 && y < 9'd256) begin dec_row_active=1'b1; dec_row_index=3'd3; dec_cell_y=y-9'd228; end
            else if (y >= 9'd272 && y < 9'd300) begin dec_row_active=1'b1; dec_row_index=3'd4; dec_cell_y=y-9'd272; end
            else if (y >= 9'd316 && y < 9'd344) begin dec_row_active=1'b1; dec_row_index=3'd5; dec_cell_y=y-9'd316; end
            else if (y >= 9'd360 && y < 9'd388) begin dec_row_active=1'b1; dec_row_index=3'd6; dec_cell_y=y-9'd360; end
            else if (y >= 9'd404 && y < 9'd432) begin dec_row_active=1'b1; dec_row_index=3'd7; dec_cell_y=y-9'd404; end
            if (dec_row_active) begin
                dec_char_index = (x - 10'd272) >> 5;
                dec_cell_x = (x - 10'd272) & 10'h01f;
            end
        end

        dec_base_pixel = C_BLACK;
        if (x >= 10'd190 && x < 10'd610 && y >= 9'd20 && y < 9'd460)
            dec_base_pixel = C_PANEL;
        if (((x == 10'd190 || x == 10'd609) && y >= 9'd20 && y < 9'd460) ||
            ((y == 9'd20 || y == 9'd459) && x >= 10'd190 && x < 10'd610))
            dec_base_pixel = C_BORDER;
    end

    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            s1_title_active <= 1'b0;
            s1_row_active <= 1'b0;
            s1_char_index <= 4'd0;
            s1_row_index <= 3'd0;
            s1_cell_x <= 6'd0;
            s1_cell_y <= 6'd0;
            s1_base_pixel <= C_BLACK;
        end else begin
            s1_title_active <= dec_title_active;
            s1_row_active <= dec_row_active;
            s1_char_index <= dec_char_index;
            s1_row_index <= dec_row_index;
            s1_cell_x <= dec_cell_x;
            s1_cell_y <= dec_cell_y;
            s1_base_pixel <= dec_base_pixel;
        end
    end

    always @(*) begin
        case (s1_row_index)
            3'd0: selected_score = scores_bcd_packed[19:0];
            3'd1: selected_score = scores_bcd_packed[39:20];
            3'd2: selected_score = scores_bcd_packed[59:40];
            3'd3: selected_score = scores_bcd_packed[79:60];
            3'd4: selected_score = scores_bcd_packed[99:80];
            3'd5: selected_score = scores_bcd_packed[119:100];
            3'd6: selected_score = scores_bcd_packed[139:120];
            default: selected_score = scores_bcd_packed[159:140];
        endcase

        selected_char = " ";
        if (s1_title_active)
            selected_char = title_char(s1_char_index);
        else if (s1_row_active) begin
            if (s1_char_index == 4'd0)
                selected_char = digit_char({1'b0, s1_row_index} + 4'd1);
            else if (s1_char_index == 4'd1)
                selected_char = ".";
            else if (s1_row_index < score_count) begin
                case (s1_char_index)
                    4'd3: selected_char = digit_char(selected_score[19:16]);
                    4'd4: selected_char = digit_char(selected_score[15:12]);
                    4'd5: selected_char = digit_char(selected_score[11:8]);
                    4'd6: selected_char = digit_char(selected_score[7:4]);
                    4'd7: selected_char = digit_char(selected_score[3:0]);
                    default: selected_char = " ";
                endcase
            end else if (s1_char_index >= 4'd3 && s1_char_index <= 4'd5)
                selected_char = "-";
        end
    end

    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            s2_glyph_char <= " ";
            s2_glyph_col <= 3'd0;
            s2_glyph_row <= 3'd0;
            s2_glyph_window <= 1'b0;
            s2_title_active <= 1'b0;
            s2_base_pixel <= C_BLACK;
        end else begin
            s2_glyph_char <= selected_char;
            s2_glyph_col <= (s1_cell_x - 6'd4) >> 2;
            s2_glyph_row <= s1_cell_y[4:2];
            s2_glyph_window <= (s1_title_active || s1_row_active) &&
                               s1_cell_x >= 6'd4 && s1_cell_x < 6'd24 &&
                               s1_cell_y < 6'd28;
            s2_title_active <= s1_title_active;
            s2_base_pixel <= s1_base_pixel;
        end
    end

    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            s3_glyph_line <= 5'd0;
            s3_glyph_col <= 3'd0;
            s3_glyph_window <= 1'b0;
            s3_title_active <= 1'b0;
            s3_base_pixel <= C_BLACK;
        end else begin
            s3_glyph_line <= font_row(s2_glyph_char, s2_glyph_row);
            s3_glyph_col <= s2_glyph_col;
            s3_glyph_window <= s2_glyph_window;
            s3_title_active <= s2_title_active;
            s3_base_pixel <= s2_base_pixel;
        end
    end

    always @(*) begin
        s3_glyph_on = 1'b0;
        if (s3_glyph_window) begin
            case (s3_glyph_col)
                3'd0: s3_glyph_on = s3_glyph_line[4];
                3'd1: s3_glyph_on = s3_glyph_line[3];
                3'd2: s3_glyph_on = s3_glyph_line[2];
                3'd3: s3_glyph_on = s3_glyph_line[1];
                3'd4: s3_glyph_on = s3_glyph_line[0];
                default: s3_glyph_on = 1'b0;
            endcase
        end
    end

    always @(posedge clk or negedge resetn) begin
        if (!resetn)
            pixel <= C_BLACK;
        else if (s3_glyph_on)
            pixel <= s3_title_active ? C_GOLD : C_CYAN;
        else
            pixel <= s3_base_pixel;
    end

endmodule

`default_nettype wire
