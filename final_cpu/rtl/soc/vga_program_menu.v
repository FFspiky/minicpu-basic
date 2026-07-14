`timescale 1ns / 1ps
`default_nettype none

module vga_program_menu(
    input  wire        clk,
    input  wire        resetn,
    input  wire [3:0]  selected_slot,
    input  wire [15:0] slot_valid,
    input  wire [7:0]  status,
    input  wire [1:0]  system_mode,
    input  wire [1:0]  led_rg0,
    input  wire [1:0]  led_rg1,
    output wire        vga_hsync,
    output wire        vga_vsync,
    output wire [3:0]  vga_r,
    output wire [3:0]  vga_g,
    output wire [3:0]  vga_b
);
    localparam H_ACTIVE=640, H_FRONT=16, H_SYNC=96, H_TOTAL=800;
    localparam V_ACTIVE=480, V_FRONT=10, V_SYNC=2, V_TOTAL=525;
    reg [1:0] pixel_div;
    reg [9:0] h_count;
    reg [9:0] v_count;
    wire pixel_ce = pixel_div == 2'd3;

    always @(posedge clk)
    begin
        if (!resetn)
        begin
            pixel_div <= 0; h_count <= 0; v_count <= 0;
        end
        else
        begin
            pixel_div <= pixel_div + 1'b1;
            if (pixel_ce)
            begin
                if (h_count == H_TOTAL-1)
                begin
                    h_count <= 0;
                    v_count <= (v_count == V_TOTAL-1) ? 0 : v_count + 1'b1;
                end
                else h_count <= h_count + 1'b1;
            end
        end
    end

    function [7:0] hex_char;
        input [3:0] value;
        begin hex_char = value < 10 ? "0" + value : "A" + value - 10; end
    endfunction

    function [7:0] title_char;
        input [5:0] pos;
        begin
            case(pos)
                0:title_char="L"; 1:title_char="A"; 2:title_char="3"; 3:title_char="2"; 4:title_char=" ";
                5:title_char="P"; 6:title_char="R"; 7:title_char="O"; 8:title_char="G"; 9:title_char="R";
                10:title_char="A"; 11:title_char="M"; 12:title_char=" "; 13:title_char="M"; 14:title_char="A";
                15:title_char="N"; 16:title_char="A"; 17:title_char="G"; 18:title_char="E"; 19:title_char="R";
                default: title_char=" ";
            endcase
        end
    endfunction

    function [7:0] name_char;
        input [3:0] slot;
        input [5:0] pos;
        begin
            if (slot == 0)
                case(pos) 0:name_char="R";1:name_char="A";2:name_char="C";3:name_char="I";4:name_char="N";5:name_char="G";6:name_char=" ";7:name_char="G";8:name_char="A";9:name_char="M";10:name_char="E";default:name_char=" ";endcase
            else if (slot == 1)
                case(pos) 0:name_char="C";1:name_char="P";2:name_char="U";3:name_char=" ";4:name_char="S";5:name_char="E";6:name_char="L";7:name_char="F";8:name_char=" ";9:name_char="T";10:name_char="E";11:name_char="S";12:name_char="T";default:name_char=" ";endcase
            else
                case(pos) 0:name_char="P";1:name_char="R";2:name_char="O";3:name_char="G";4:name_char="R";5:name_char="A";6:name_char="M";7:name_char=" ";8:name_char=hex_char(slot);default:name_char=" ";endcase
        end
    endfunction

    function [7:0] status_char;
        input [7:0] value;
        input [5:0] pos;
        begin
            if (value == 8'hff)
                case(pos) 0:status_char="E";1:status_char="R";2:status_char="R";3:status_char="O";4:status_char="R";default:status_char=" ";endcase
            else if (value == 0)
                case(pos) 0:status_char="R";1:status_char="E";2:status_char="A";3:status_char="D";4:status_char="Y";default:status_char=" ";endcase
            else
                case(pos) 0:status_char="L";1:status_char="O";2:status_char="A";3:status_char="D";4:status_char="I";5:status_char="N";6:status_char="G";default:status_char=" ";endcase
        end
    endfunction

    function [7:0] selftest_char;
        input [1:0] result;
        input [5:0] pos;
        begin
            if(result==2'd1)
                case(pos)0:selftest_char="P";1:selftest_char="A";2,3:selftest_char="S";4:selftest_char="E";5:selftest_char="D";default:selftest_char=" ";endcase
            else if(result==2'd2)
                case(pos)0:selftest_char="F";1:selftest_char="A";2:selftest_char="I";3:selftest_char="L";4:selftest_char="E";5:selftest_char="D";default:selftest_char=" ";endcase
            else
                case(pos)0:selftest_char="R";1:selftest_char="U";2:selftest_char="N";3:selftest_char="N";4:selftest_char="I";5:selftest_char="N";6:selftest_char="G";default:selftest_char=" ";endcase
        end
    endfunction

    function [7:0] generic_title_char;
        input [5:0] pos;
        begin
            case(pos)
                0:generic_title_char="G"; 1:generic_title_char="E"; 2:generic_title_char="N";
                3:generic_title_char="E"; 4:generic_title_char="R"; 5:generic_title_char="I";
                6:generic_title_char="C"; 7:generic_title_char=" "; 8:generic_title_char="P";
                9:generic_title_char="R"; 10:generic_title_char="O"; 11:generic_title_char="G";
                12:generic_title_char="R"; 13:generic_title_char="A"; 14:generic_title_char="M";
                default:generic_title_char=" ";
            endcase
        end
    endfunction

    function [4:0] font_row;
        input [7:0] ch;
        input [2:0] row;
        begin
            font_row=0;
            case(ch)
                "A":case(row)0:font_row=5'b01110;1,2:font_row=5'b10001;3:font_row=5'b11111;4,5,6:font_row=5'b10001;endcase
                "B":case(row)0,3,6:font_row=5'b11110;1,2,4,5:font_row=5'b10001;endcase
                "C":case(row)0,6:font_row=5'b01111;1,2,3,4,5:font_row=5'b10000;endcase
                "D":case(row)0,6:font_row=5'b11110;1,2,3,4,5:font_row=5'b10001;endcase
                "E":case(row)0,6:font_row=5'b11111;1,2,4,5:font_row=5'b10000;3:font_row=5'b11110;endcase
                "F":case(row)0:font_row=5'b11111;1,2,4,5,6:font_row=5'b10000;3:font_row=5'b11110;endcase
                "G":case(row)0,6:font_row=5'b01110;1,2:font_row=5'b10000;3,4,5:font_row=5'b10111;endcase
                "H":case(row)0,1,2,4,5,6:font_row=5'b10001;3:font_row=5'b11111;endcase
                "I":case(row)0,6:font_row=5'b11111;1,2,3,4,5:font_row=5'b00100;endcase
                "J":case(row)0:font_row=5'b00111;1,2,3,4:font_row=5'b00010;5:font_row=5'b10010;6:font_row=5'b01100;endcase
                "K":case(row)0,6:font_row=5'b10001;1,5:font_row=5'b10010;2,4:font_row=5'b10100;3:font_row=5'b11000;endcase
                "L":case(row)0,1,2,3,4,5:font_row=5'b10000;6:font_row=5'b11111;endcase
                "M":case(row)0:font_row=5'b10001;1:font_row=5'b11011;2:font_row=5'b10101;3,4,5,6:font_row=5'b10001;endcase
                "N":case(row)0:font_row=5'b10001;1:font_row=5'b11001;2:font_row=5'b10101;3:font_row=5'b10011;4,5,6:font_row=5'b10001;endcase
                "O":case(row)0,6:font_row=5'b01110;1,2,3,4,5:font_row=5'b10001;endcase
                "P":case(row)0,3:font_row=5'b11110;1,2:font_row=5'b10001;4,5,6:font_row=5'b10000;endcase
                "Q":case(row)0:font_row=5'b01110;1,2,3,4:font_row=5'b10001;5:font_row=5'b10011;6:font_row=5'b01111;endcase
                "R":case(row)0,3:font_row=5'b11110;1,2:font_row=5'b10001;4:font_row=5'b10100;5:font_row=5'b10010;6:font_row=5'b10001;endcase
                "S":case(row)0:font_row=5'b01111;1,2:font_row=5'b10000;3:font_row=5'b01110;4,5:font_row=5'b00001;6:font_row=5'b11110;endcase
                "T":case(row)0:font_row=5'b11111;1,2,3,4,5,6:font_row=5'b00100;endcase
                "U":case(row)0,1,2,3,4,5:font_row=5'b10001;6:font_row=5'b01110;endcase
                "V":case(row)0,1,2,3,4:font_row=5'b10001;5:font_row=5'b01010;6:font_row=5'b00100;endcase
                "W":case(row)0,1,2,3:font_row=5'b10001;4:font_row=5'b10101;5:font_row=5'b11011;6:font_row=5'b10001;endcase
                "X":case(row)0,6:font_row=5'b10001;1,5:font_row=5'b01010;2,3,4:font_row=5'b00100;endcase
                "Y":case(row)0:font_row=5'b10001;1:font_row=5'b01010;2,3,4,5,6:font_row=5'b00100;endcase
                "Z":case(row)0,6:font_row=5'b11111;1:font_row=5'b00010;2:font_row=5'b00100;3:font_row=5'b01000;4,5:font_row=5'b10000;endcase
                "0":case(row)0,6:font_row=5'b01110;1,2,3,4,5:font_row=5'b10001;endcase
                "1":case(row)0:font_row=5'b00100;1:font_row=5'b01100;2,3,4,5:font_row=5'b00100;6:font_row=5'b01110;endcase
                "2":case(row)0:font_row=5'b01110;1:font_row=5'b10001;2:font_row=5'b00001;3:font_row=5'b00010;4:font_row=5'b00100;5:font_row=5'b01000;6:font_row=5'b11111;endcase
                "3":case(row)0,6:font_row=5'b11110;1,2,4,5:font_row=5'b00001;3:font_row=5'b01110;endcase
                "4":case(row)0,1,2:font_row=5'b10010;3:font_row=5'b11111;4,5,6:font_row=5'b00010;endcase
                "5":case(row)0:font_row=5'b11111;1,2:font_row=5'b10000;3:font_row=5'b11110;4,5:font_row=5'b00001;6:font_row=5'b11110;endcase
                "6":case(row)0:font_row=5'b01110;1,2:font_row=5'b10000;3:font_row=5'b11110;4,5:font_row=5'b10001;6:font_row=5'b01110;endcase
                "7":case(row)0:font_row=5'b11111;1:font_row=5'b00001;2:font_row=5'b00010;3:font_row=5'b00100;4,5,6:font_row=5'b01000;endcase
                "8":case(row)0,3,6:font_row=5'b01110;1,2,4,5:font_row=5'b10001;endcase
                "9":case(row)0:font_row=5'b01110;1,2:font_row=5'b10001;3:font_row=5'b01111;4,5:font_row=5'b00001;6:font_row=5'b01110;endcase
                ">":case(row)1,5:font_row=5'b01000;2,4:font_row=5'b00100;3:font_row=5'b00010;endcase
                "-":if(row==3)font_row=5'b01110;
                default:font_row=0;
            endcase
        end
    endfunction

    wire active_video = h_count < H_ACTIVE && v_count < V_ACTIVE;
    wire [5:0] char_col = h_count[9:4];
    wire [4:0] char_row = v_count[8:4];
    reg [7:0] character;
    reg selected_line;
    reg [3:0] row_slot;
    always @(*)
    begin
        character=" "; selected_line=1'b0; row_slot=0;
        if (char_row == 2 && char_col >= 10 && char_col < 30)
            character = (system_mode == 2'd2) ? name_char(4'd1, char_col-10) :
                        (system_mode == 2'd3) ? generic_title_char(char_col-10) :
                                                title_char(char_col-10);
        else if(system_mode==2'd2 && char_row==10 && char_col>=12 && char_col<20)
            character=selftest_char((led_rg0==2'd1 && led_rg1==2'd1) ? 2'd1 :
                                    ((led_rg0==2'd2 && led_rg1==2'd2) ? 2'd2 : 2'd0),char_col-12);
        else if(system_mode==2'd3 && char_row==10 && char_col>=12 && char_col<19)
            character=selftest_char(2'd0,char_col-12);
        else if (system_mode==2'd0 && char_row >= 6 && char_row < 22)
        begin
            row_slot=char_row-6;
            selected_line=row_slot==selected_slot;
            if(char_col==2) character=selected_line?">":" ";
            else if(char_col==4) character=hex_char(row_slot);
            else if(char_col>=7 && char_col<21)
                character=slot_valid[row_slot]?name_char(row_slot,char_col-7):
                          ((char_col==7)?"<":(char_col==8)?"E":(char_col==9)?"M":
                           (char_col==10)?"P":(char_col==11)?"T":(char_col==12)?"Y":
                           (char_col==13)?">":" ");
        end
        else if(char_row==26 && char_col>=2 && char_col<12)
            character=status_char(status,char_col-2);
    end

    wire [2:0] glyph_x=h_count[3:1];
    wire [2:0] glyph_y=v_count[3:1];
    wire [4:0] glyph=font_row(character,glyph_y);
    wire glyph_on=(glyph_x<5)&&(glyph_y<7)&&glyph[4-glyph_x];
    wire [11:0] foreground=selected_line?12'h021:12'h0f8;
    wire [11:0] background=selected_line?12'hbd2:12'h013;
    wire [11:0] color=glyph_on?foreground:background;

    assign vga_hsync=~((h_count>=H_ACTIVE+H_FRONT)&&(h_count<H_ACTIVE+H_FRONT+H_SYNC));
    assign vga_vsync=~((v_count>=V_ACTIVE+V_FRONT)&&(v_count<V_ACTIVE+V_FRONT+V_SYNC));
    assign vga_r=active_video?color[11:8]:0;
    assign vga_g=active_video?color[7:4]:0;
    assign vga_b=active_video?color[3:0]:0;
endmodule

`default_nettype wire
