`timescale 1ns / 1ps
`default_nettype none

module vga_scoreboard_renderer(
    input  wire [8:0]   x,
    input  wire [8:0]   y,
    input  wire [19:0]  current_score_bcd,
    input  wire [159:0] scores_bcd_packed,
    input  wire [3:0]   score_count,
    output reg  [15:0]  pixel
);
    localparam [15:0] C_BLACK = 16'h0000;
    localparam [15:0] C_WHITE = 16'hffff;
    localparam [15:0] C_GOLD  = 16'hfec0;
    localparam [15:0] C_CYAN  = 16'h07ff;

    reg        glyph_active;
    reg [7:0]  glyph_char;
    reg [2:0]  glyph_col;
    reg [2:0]  glyph_row;
    reg [15:0] glyph_color;
    reg [4:0]  glyph_bits;
    reg [19:0] selected_score;
    integer    char_index;
    integer    row_index;
    integer    rel_x;
    integer    rel_y;

    function [7:0] digit_char;
        input [3:0] digit;
        begin
            digit_char = (digit <= 4'd9) ? (8'h30 + digit) : " ";
        end
    endfunction

    function [7:0] score_digit;
        input [19:0] score;
        input [2:0] index;
        begin
            case (index)
                3'd0: score_digit = digit_char(score[19:16]);
                3'd1: score_digit = digit_char(score[15:12]);
                3'd2: score_digit = digit_char(score[11:8]);
                3'd3: score_digit = digit_char(score[7:4]);
                default: score_digit = digit_char(score[3:0]);
            endcase
        end
    endfunction

    function [7:0] title_char;
        input [3:0] index;
        begin
            case (index)
                4'd0: title_char="L"; 4'd1: title_char="E";
                4'd2: title_char="A"; 4'd3: title_char="D";
                4'd4: title_char="E"; 4'd5: title_char="R";
                4'd6: title_char="B"; 4'd7: title_char="O";
                4'd8: title_char="A"; 4'd9: title_char="R";
                4'd10: title_char="D"; default: title_char=" ";
            endcase
        end
    endfunction

    function [7:0] score_title_char;
        input [2:0] index;
        begin
            case (index)
                3'd0: score_title_char="S"; 3'd1: score_title_char="C";
                3'd2: score_title_char="O"; 3'd3: score_title_char="R";
                3'd4: score_title_char="E"; default: score_title_char=" ";
            endcase
        end
    endfunction

    function [4:0] font_row;
        input [7:0] ch;
        input [2:0] row;
        begin
            font_row = 5'b00000;
            case (ch)
                "A": case (row) 0:font_row=5'b01110; 1,2:font_row=5'b10001; 3:font_row=5'b11111; 4,5,6:font_row=5'b10001; default:font_row=0; endcase
                "B": case (row) 0,3,6:font_row=5'b11110; 1,2,4,5:font_row=5'b10001; default:font_row=0; endcase
                "C": case (row) 0,6:font_row=5'b01111; 1,2,3,4,5:font_row=5'b10000; default:font_row=0; endcase
                "D": case (row) 0,6:font_row=5'b11110; 1,2,3,4,5:font_row=5'b10001; default:font_row=0; endcase
                "E": case (row) 0,6:font_row=5'b11111; 1,2,4,5:font_row=5'b10000; 3:font_row=5'b11110; default:font_row=0; endcase
                "L": case (row) 0,1,2,3,4,5:font_row=5'b10000; 6:font_row=5'b11111; default:font_row=0; endcase
                "O": case (row) 0,6:font_row=5'b01110; 1,2,3,4,5:font_row=5'b10001; default:font_row=0; endcase
                "R": case (row) 0,3:font_row=5'b11110; 1,2:font_row=5'b10001; 4:font_row=5'b10100; 5:font_row=5'b10010; 6:font_row=5'b10001; default:font_row=0; endcase
                "S": case (row) 0:font_row=5'b01111; 1,2:font_row=5'b10000; 3:font_row=5'b01110; 4,5:font_row=5'b00001; 6:font_row=5'b11110; default:font_row=0; endcase
                "0": case (row) 0,6:font_row=5'b01110; 1,2,3,4,5:font_row=5'b10001; default:font_row=0; endcase
                "1": case (row) 0:font_row=5'b00100; 1:font_row=5'b01100; 2,3,4,5:font_row=5'b00100; 6:font_row=5'b01110; default:font_row=0; endcase
                "2": case (row) 0:font_row=5'b01110; 1:font_row=5'b10001; 2:font_row=5'b00001; 3:font_row=5'b00010; 4:font_row=5'b00100; 5:font_row=5'b01000; 6:font_row=5'b11111; default:font_row=0; endcase
                "3": case (row) 0,6:font_row=5'b11110; 1,2,4,5:font_row=5'b00001; 3:font_row=5'b01110; default:font_row=0; endcase
                "4": case (row) 0:font_row=5'b00010; 1:font_row=5'b00110; 2:font_row=5'b01010; 3:font_row=5'b10010; 4:font_row=5'b11111; 5,6:font_row=5'b00010; default:font_row=0; endcase
                "5": case (row) 0:font_row=5'b11111; 1,2:font_row=5'b10000; 3:font_row=5'b11110; 4,5:font_row=5'b00001; 6:font_row=5'b11110; default:font_row=0; endcase
                "6": case (row) 0,6:font_row=5'b01110; 1,2:font_row=5'b10000; 3:font_row=5'b11110; 4,5:font_row=5'b10001; default:font_row=0; endcase
                "7": case (row) 0:font_row=5'b11111; 1:font_row=5'b00001; 2:font_row=5'b00010; 3:font_row=5'b00100; 4,5,6:font_row=5'b01000; default:font_row=0; endcase
                "8": case (row) 0,3,6:font_row=5'b01110; 1,2,4,5:font_row=5'b10001; default:font_row=0; endcase
                "9": case (row) 0,6:font_row=5'b01110; 1,2:font_row=5'b10001; 3:font_row=5'b01111; 4,5:font_row=5'b00001; default:font_row=0; endcase
                ".": case (row) 6:font_row=5'b00100; default:font_row=0; endcase
                "-": case (row) 3:font_row=5'b01110; default:font_row=0; endcase
                default: font_row=5'b00000;
            endcase
        end
    endfunction

    always @(*) begin
        glyph_active = 1'b0;
        glyph_char = " ";
        glyph_col = 3'd0;
        glyph_row = 3'd0;
        glyph_color = C_WHITE;
        selected_score = 20'd0;
        char_index = 0;
        row_index = 0;
        rel_x = 0;
        rel_y = 0;

        // SCORE: 5 characters, scale 3, 18-pixel cells.
        if (x >= 9'd99 && x < 9'd189 && y >= 9'd34 && y < 9'd55) begin
            rel_x = x - 9'd99;
            rel_y = y - 9'd34;
            char_index = rel_x / 18;
            glyph_char = score_title_char(char_index[2:0]);
            glyph_col = (rel_x % 18) / 3;
            glyph_row = rel_y / 3;
            glyph_active = ((rel_x % 18) < 15);
            glyph_color = C_CYAN;
        end
        // Current score: 5 characters, scale 6, 36-pixel cells.
        else if (x >= 9'd54 && x < 9'd234 && y >= 9'd78 && y < 9'd120) begin
            rel_x = x - 9'd54;
            rel_y = y - 9'd78;
            char_index = rel_x / 36;
            glyph_char = score_digit(current_score_bcd, char_index[2:0]);
            glyph_col = (rel_x % 36) / 6;
            glyph_row = rel_y / 6;
            glyph_active = ((rel_x % 36) < 30);
            glyph_color = C_GOLD;
        end
        // LEADERBOARD: 11 characters, scale 3.
        else if (x >= 9'd45 && x < 9'd243 && y >= 9'd164 && y < 9'd185) begin
            rel_x = x - 9'd45;
            rel_y = y - 9'd164;
            char_index = rel_x / 18;
            glyph_char = title_char(char_index[3:0]);
            glyph_col = (rel_x % 18) / 3;
            glyph_row = rel_y / 3;
            glyph_active = ((rel_x % 18) < 15);
            glyph_color = C_CYAN;
        end
        // Eight rows: "N. 00000", scale 3.
        else if (x >= 9'd72 && x < 9'd216 && y >= 9'd210 && y < 9'd458) begin
            rel_x = x - 9'd72;
            rel_y = y - 9'd210;
            row_index = rel_y / 31;
            if (row_index < 8 && (rel_y % 31) < 21) begin
                char_index = rel_x / 18;
                case (row_index)
                    0:selected_score=scores_bcd_packed[19:0]; 1:selected_score=scores_bcd_packed[39:20];
                    2:selected_score=scores_bcd_packed[59:40]; 3:selected_score=scores_bcd_packed[79:60];
                    4:selected_score=scores_bcd_packed[99:80]; 5:selected_score=scores_bcd_packed[119:100];
                    6:selected_score=scores_bcd_packed[139:120]; default:selected_score=scores_bcd_packed[159:140];
                endcase
                if (char_index == 0)
                    glyph_char = digit_char(row_index + 1);
                else if (char_index == 1)
                    glyph_char = ".";
                else if (char_index >= 3 && char_index <= 7 && row_index < score_count)
                    glyph_char = score_digit(selected_score, char_index - 3);
                else if (char_index >= 4 && char_index <= 6 && row_index >= score_count)
                    glyph_char = "-";
                glyph_col = (rel_x % 18) / 3;
                glyph_row = (rel_y % 31) / 3;
                glyph_active = (char_index < 8) && ((rel_x % 18) < 15);
                glyph_color = C_WHITE;
            end
        end

        glyph_bits = font_row(glyph_char, glyph_row);
        pixel = C_BLACK;
        if (glyph_active && glyph_col < 5 && glyph_bits[4 - glyph_col])
            pixel = glyph_color;
    end
endmodule

`default_nettype wire
