`timescale 1ns / 1ps
`default_nettype none

module ps2_game_keyboard(
    input  wire        clk,
    input  wire        resetn,
    input  wire        ps2_clk,
    input  wire        ps2_data,
    output reg  [15:0] game_keys,
    output reg  [7:0]  last_scan_code,
    output reg         scan_valid
);
    reg [2:0] ps2_clk_sync;
    reg [1:0] ps2_data_sync;
    reg [3:0] bit_count;
    reg [7:0] scan_shift;
    reg       parity_xor;
    reg       extended;
    reg       released;

    wire ps2_falling = ps2_clk_sync[2] & ~ps2_clk_sync[1];
    wire data_sample = ps2_data_sync[1];

    always @(posedge clk or negedge resetn)
    begin
        if (!resetn)
        begin
            ps2_clk_sync  <= 3'b111;
            ps2_data_sync <= 2'b11;
        end
        else
        begin
            ps2_clk_sync  <= {ps2_clk_sync[1:0], ps2_clk};
            ps2_data_sync <= {ps2_data_sync[0], ps2_data};
        end
    end

    always @(posedge clk or negedge resetn)
    begin
        if (!resetn)
        begin
            bit_count      <= 4'd0;
            scan_shift     <= 8'd0;
            parity_xor     <= 1'b0;
            extended       <= 1'b0;
            released       <= 1'b0;
            game_keys      <= 16'd0;
            last_scan_code <= 8'd0;
            scan_valid     <= 1'b0;
        end
        else
        begin
            scan_valid <= 1'b0;
            if (ps2_falling)
            begin
                case (bit_count)
                    4'd0:
                    begin
                        if (!data_sample)
                        begin
                            bit_count  <= 4'd1;
                            parity_xor <= 1'b0;
                        end
                    end
                    4'd1, 4'd2, 4'd3, 4'd4,
                    4'd5, 4'd6, 4'd7, 4'd8:
                    begin
                        scan_shift[bit_count - 1'b1] <= data_sample;
                        parity_xor <= parity_xor ^ data_sample;
                        bit_count  <= bit_count + 1'b1;
                    end
                    4'd9:
                    begin
                        parity_xor <= parity_xor ^ data_sample;
                        bit_count  <= 4'd10;
                    end
                    default:
                    begin
                        bit_count <= 4'd0;
                        if (data_sample && parity_xor)
                        begin
                            last_scan_code <= scan_shift;
                            scan_valid <= 1'b1;
                            if (scan_shift == 8'he0)
                            begin
                                extended <= 1'b1;
                            end
                            else if (scan_shift == 8'hf0)
                            begin
                                released <= 1'b1;
                            end
                            else
                            begin
                                if (extended)
                                begin
                                    case (scan_shift)
                                        8'h75: game_keys[10] <= ~released; // Up
                                        8'h72: game_keys[14] <= ~released; // Down
                                        8'h6b: game_keys[13] <= ~released; // Left
                                        8'h74: game_keys[15] <= ~released; // Right
                                        default: ;
                                    endcase
                                end
                                else if (scan_shift == 8'h29)
                                begin
                                    game_keys[12] <= ~released; // Space: soft restart
                                end
                                extended <= 1'b0;
                                released <= 1'b0;
                            end
                        end
                    end
                endcase
            end
        end
    end
endmodule

`default_nettype wire
